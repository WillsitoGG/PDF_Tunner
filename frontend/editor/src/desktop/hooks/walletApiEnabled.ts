import { connectionModeService } from "@app/services/connectionModeService";

/** Prevent the cloud-only PAYG wallet request from reaching the local backend. */
export async function canFetchPaygWallet(): Promise<boolean> {
  return (await connectionModeService.getCurrentMode()) === "saas";
}
