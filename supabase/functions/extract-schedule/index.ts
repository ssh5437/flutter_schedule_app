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
    // 요청 본문에서 텍스트 추출
    const { text } = await req.json()

    if (!text || typeof text !== 'string') {
      return new Response(
        JSON.stringify({ error: 'text 파라미터가 필요합니다' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    if (!GEMINI_API_KEY) {
      return new Response(
        JSON.stringify({ error: 'GEMINI_API_KEY가 설정되지 않았습니다' }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Gemini API 호출
    const prompt = `다음 텍스트에서 스케줄 정보를 추출해주세요. 추출할 정보는 다음과 같습니다:
- 고객명 (name)
- 전화번호 (phone) - 숫자만 추출
- 주소 (address)
- 날짜 (date) - YYYY-MM-DD 형식
- 시간 (time) - HH:MM 형식 (24시간제)

JSON 형식으로만 응답해주세요. 값을 찾을 수 없는 경우 null을 사용하세요.
형식 예시:
{
  "name": "홍길동",
  "phone": "01012345678",
  "address": "서울시 강남구 테헤란로 123",
  "date": "2025-10-15",
  "time": "14:00"
}

텍스트:
${text}

JSON 응답:`

    const geminiResponse = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-lite:generateContent?key=${GEMINI_API_KEY}`,
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

    if (!geminiResponse.ok) {
      const errorText = await geminiResponse.text()
      console.error('Gemini API 오류:', errorText)
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
