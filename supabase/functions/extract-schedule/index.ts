import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY')

serve(async (req) => {
  // CORS 헤더 설정
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  }

  // OPTIONS 요청 처리
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 고유 요청 ID 생성 (중복 호출 추적용)
    const requestId = crypto.randomUUID()

    // 요청 본문에서 텍스트 및 작업 목록 추출
    const { text, availableWorkItems } = await req.json()

    console.log(`📥 [${requestId}] Request received:`, { text: text?.substring(0, 100), availableWorkItemsCount: availableWorkItems?.length })

    if (!text || typeof text !== 'string') {
      console.error(`❌ [${requestId}] Invalid text parameter`)
      return new Response(
        JSON.stringify({ error: 'text 파라미터가 필요합니다' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    if (!GEMINI_API_KEY) {
      console.error(`❌ [${requestId}] GEMINI_API_KEY not found`)
      return new Response(
        JSON.stringify({ error: 'GEMINI_API_KEY가 설정되지 않았습니다' }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    console.log(`✅ [${requestId}] GEMINI_API_KEY exists`)

    // Gemini API 호출 (1회만 호출되어야 함)
    const workItemsPrompt = availableWorkItems && availableWorkItems.length > 0
      ? `\n- 작업 내용 (workItems) - 문자열 배열 형식. 아래 작업 목록에서만 선택하여 추출하세요. 텍스트에 "3개", "2건" 등의 수량이 있으면 해당 작업명을 그 수량만큼 배열에 반복해서 넣으세요.
  사용 가능한 작업 목록: ${JSON.stringify(availableWorkItems)}
  예시: 텍스트에 "실외기 세척 3개"가 있으면 workItems: ["실외기 세척", "실외기 세척", "실외기 세척"]로 반환
  중요: "홈멀티 에어컨 (스탠드+벽걸이)", "2in1 에어컨 (스탠드+벽걸이)" 처럼 괄호 안에 구성 부품이 나열된 경우, 이는 하나의 복합 상품입니다. 괄호 안의 스탠드, 벽걸이 등을 별도 항목으로 추출하지 말고 앞의 상품명(홈멀티 에어컨, 2in1 에어컨 등) 하나만 추출하세요.`
      : '\n- 작업 내용 (workItems) - 문자열 배열 형식. 에어컨 청소, 세탁기 청소, 이사, 레슨 등 서비스/작업 항목을 추출. 수량이 있으면 해당 수량만큼 배열에 반복. 중요: "홈멀티 에어컨 (스탠드+벽걸이)" 처럼 괄호 안에 구성 부품이 나열된 경우 하나의 상품으로 취급하여 앞의 상품명만 추출하세요.'

    const workItemsExample = availableWorkItems && availableWorkItems.length > 0
      ? availableWorkItems.slice(0, 2)  // 처음 2개만 예시로 사용
      : ["1way 에어컨 세척", "실외기 세척"]

    const prompt = `다음 텍스트에서 스케줄 정보를 추출해주세요. 추출할 정보는 다음과 같습니다:
- 고객명 (name)
- 전화번호 (phone) - 숫자만 추출
- 주소 (address)
- 날짜 (date) - YYYY-MM-DD 형식
- 시간 (time) - HH:MM 형식 (24시간제)${workItemsPrompt}

JSON 형식으로만 응답해주세요. 값을 찾을 수 없는 경우 null을 사용하세요.
형식 예시:
{
  "name": "홍길동",
  "phone": "01012345678",
  "address": "서울시 강남구 테헤란로 123",
  "date": "2025-10-15",
  "time": "14:00",
  "workItems": ${JSON.stringify(workItemsExample)}
}

텍스트:
${text}

JSON 응답:`

    const modelVersion = 'gemini-2.5-flash-lite'
    const apiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${modelVersion}:generateContent?key=${GEMINI_API_KEY}`

    console.log(`🚀 [${requestId}] Calling Gemini API (generateContent only)...`, { model: modelVersion })

    const geminiResponse = await fetch(
      apiUrl,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          contents: [
            {
              parts: [
                {
                  text: prompt
                }
              ]
            }
          ]
        })
      }
    )

    console.log(`📡 [${requestId}] Gemini response status:`, geminiResponse.status)

    if (!geminiResponse.ok) {
      const errorText = await geminiResponse.text()
      console.error(`❌ [${requestId}] Gemini API 오류:`, errorText)
      return new Response(
        JSON.stringify({ error: 'Gemini API 호출 실패', details: errorText }),
        {
          status: geminiResponse.status,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const geminiData = await geminiResponse.json()

    // Gemini 응답에서 텍스트 추출
    const responseText = geminiData?.candidates?.[0]?.content?.parts?.[0]?.text

    if (!responseText) {
      return new Response(
        JSON.stringify({ error: 'Gemini 응답을 파싱할 수 없습니다' }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // JSON 추출 (마크다운 코드 블록 제거)
    let jsonText = responseText.trim()
    if (jsonText.startsWith('```json')) {
      jsonText = jsonText.substring(7)
    } else if (jsonText.startsWith('```')) {
      jsonText = jsonText.substring(3)
    }
    if (jsonText.endsWith('```')) {
      jsonText = jsonText.substring(0, jsonText.length - 3)
    }
    jsonText = jsonText.trim()

    // JSON 파싱
    const extractedData = JSON.parse(jsonText)

    console.log(`✅ [${requestId}] Successfully extracted data:`, extractedData)
    console.log(`🎯 [${requestId}] Total Gemini API calls: 1 (generateContent only)`)

    return new Response(
      JSON.stringify({ data: extractedData }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )

  } catch (error) {
    console.error('오류:', error)
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : '알 수 없는 오류가 발생했습니다' }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
