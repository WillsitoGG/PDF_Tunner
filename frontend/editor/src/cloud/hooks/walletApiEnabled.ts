/** The SaaS/web build has a PAYG backend. Platform-specific desktop overrides
 * gate cloud billing when the embedded local backend is selected. */
export async function canFetchPaygWallet(): Promise<boolean> {
  return true;
}
