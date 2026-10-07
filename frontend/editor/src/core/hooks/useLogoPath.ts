import { useMemo } from "react";
import { BASE_PATH } from "@app/constants/app";

/** Theme-specific no-text logo SVG URLs under the active variant folder (`modern-logo` / `classic-logo`). */
export function useLogoPath(): { dark: string; light: string } {
  return useMemo(
    () => ({
      dark: `${BASE_PATH}/pdf-tunner/icon-dark.svg`,
      light: `${BASE_PATH}/pdf-tunner/icon-light.svg`,
    }),
    [],
  );
}
