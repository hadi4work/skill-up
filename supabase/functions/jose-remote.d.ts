/** تعريفات للاستيراد من deno.land (المحرّر لا يحمّل الوحدة محلياً) */
declare module "https://deno.land/x/jose@v5.2.3/index.ts" {
  export function importPKCS8(
    pkcs8: string,
    alg: string,
  ): Promise<CryptoKey>;

  export class SignJWT {
    constructor(payload?: Record<string, unknown>);
    setProtectedHeader(parameters: Record<string, unknown>): this;
    setIssuer(issuer: string): this;
    setSubject(subject: string): this;
    setAudience(audience: string | string[]): this;
    setIssuedAt(input?: number): this;
    setExpirationTime(input: string | number | Date): this;
    sign(key: CryptoKey, options?: unknown): Promise<string>;
  }
}
