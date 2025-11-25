// Supabase Edge Function: Google Play 구매 검증
// deno-lint-ignore-file no-explicit-any

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface VerifyRequest {
  productId: string;
  purchaseToken: string;
  packageName: string;
}

interface GooglePlayVerificationResponse {
  kind: string;
  purchaseTimeMillis: string;
  purchaseState: number;
  consumptionState: number;
  orderId: string;
  acknowledgementState: number;
  expiryTimeMillis?: string;
}

serve(async (req) => {
  // CORS preflight 처리
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // 요청 본문 파싱
    const { productId, purchaseToken, packageName }: VerifyRequest = await req.json();

    if (!productId || !purchaseToken || !packageName) {
      return new Response(
        JSON.stringify({ error: 'Missing required parameters' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Google Play Developer API 인증 정보
    const serviceAccountEmail = Deno.env.get('GOOGLE_SERVICE_ACCOUNT_EMAIL');
    const privateKey = Deno.env.get('GOOGLE_PRIVATE_KEY')?.replace(/\\n/g, '\n');

    if (!serviceAccountEmail || !privateKey) {
      console.error('Missing Google service account credentials');
      return new Response(
        JSON.stringify({ error: 'Server configuration error' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // JWT 토큰 생성 (Google API 인증용)
    const jwtToken = await createJWT(serviceAccountEmail, privateKey);

    // Google Play Developer API 호출
    const verifyUrl = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packageName}/purchases/subscriptionsv2/tokens/${purchaseToken}`;

    const verifyResponse = await fetch(verifyUrl, {
      headers: {
        'Authorization': `Bearer ${jwtToken}`,
        'Content-Type': 'application/json',
      },
    });

    if (!verifyResponse.ok) {
      const errorText = await verifyResponse.text();
      console.error('Google API error:', errorText);
      return new Response(
        JSON.stringify({
          error: 'Purchase verification failed',
          valid: false,
          details: errorText
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const verificationData: GooglePlayVerificationResponse = await verifyResponse.json();

    // 구매 상태 확인 (0 = 구매됨, 1 = 취소됨, 2 = 보류 중)
    const isValid = verificationData.purchaseState === 0;
    const purchaseDate = new Date(parseInt(verificationData.purchaseTimeMillis));
    const expiryDate = verificationData.expiryTimeMillis
      ? new Date(parseInt(verificationData.expiryTimeMillis))
      : null;

    // Supabase 클라이언트 초기화
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    // 사용자 인증 토큰에서 userId 추출
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Missing authorization header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const token = authHeader.replace('Bearer ', '');
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);

    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Invalid authorization token' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 검증 성공 시 Supabase profiles 업데이트
    if (isValid && expiryDate) {
      const { error: updateError } = await supabase
        .from('profiles')
        .update({
          membership_tier: 'plus',
          membership_expires_at: expiryDate.toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq('id', user.id);

      if (updateError) {
        console.error('Failed to update profile:', updateError);
        return new Response(
          JSON.stringify({
            error: 'Failed to update user profile',
            valid: false,
            details: updateError.message
          }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
    } else if (!isValid) {
      // 구매가 유효하지 않은 경우 (취소됨, 보류 중 등)
      return new Response(
        JSON.stringify({
          valid: false,
          error: 'Purchase is not valid',
          purchaseState: verificationData.purchaseState,
          details: verificationData.purchaseState === 1 ? 'Purchase cancelled' : 'Purchase pending'
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    } else if (!expiryDate) {
      // 만료 날짜가 없는 경우 (구독 타입이 아닌 경우)
      return new Response(
        JSON.stringify({
          valid: false,
          error: 'No expiry date found',
          details: 'This might not be a subscription purchase'
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 응답 반환
    return new Response(
      JSON.stringify({
        valid: isValid,
        productId,
        orderId: verificationData.orderId,
        purchaseDate: purchaseDate.toISOString(),
        expiryDate: expiryDate?.toISOString(),
        purchaseState: verificationData.purchaseState,
        acknowledgementState: verificationData.acknowledgementState,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Error verifying purchase:', error);
    return new Response(
      JSON.stringify({
        error: 'Internal server error',
        valid: false,
        message: error.message
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

// JWT 토큰 생성 함수 (Google API 인증용)
async function createJWT(email: string, privateKey: string): Promise<string> {
  const header = {
    alg: 'RS256',
    typ: 'JWT',
  };

  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: email,
    scope: 'https://www.googleapis.com/auth/androidpublisher',
    aud: 'https://oauth2.googleapis.com/token',
    exp: now + 3600,
    iat: now,
  };

  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const signatureInput = `${encodedHeader}.${encodedPayload}`;

  // RSA 서명 생성
  const privateKeyObj = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(privateKey),
    {
      name: 'RSASSA-PKCS1-v1_5',
      hash: 'SHA-256',
    },
    false,
    ['sign']
  );

  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    privateKeyObj,
    new TextEncoder().encode(signatureInput)
  );

  const encodedSignature = base64UrlEncode(signature);
  return `${signatureInput}.${encodedSignature}`;
}

function base64UrlEncode(data: string | ArrayBuffer): string {
  let base64: string;
  if (typeof data === 'string') {
    base64 = btoa(data);
  } else {
    base64 = btoa(String.fromCharCode(...new Uint8Array(data)));
  }
  return base64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '');
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}
