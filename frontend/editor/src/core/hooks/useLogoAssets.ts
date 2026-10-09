import { useMemo } from "react";
import { BASE_PATH } from "@app/constants/app";

const LOGO_FOLDER = "modern-logo";

export function useLogoAssets() {
  return useMemo(() => {
    const folderPath = `${BASE_PATH}/${LOGO_FOLDER}`;
    const brandPath = `${BASE_PATH}/pdf-tunner`;

    return {
      folderPath,
      getAssetPath: (name: string) => `${folderPath}/${name}`,
      wordmark: {
        black: `${brandPath}/wordmark-black.svg`,
        grey: `${brandPath}/wordmark-grey.svg`,
        white: `${brandPath}/wordmark-white.svg`,
      },
      tooltipLogo: `${brandPath}/icon-light.svg`,
      firstPage: `${folderPath}/Firstpage.png`,
      favicon: `${brandPath}/icon-light.svg`,
      logo192: `${brandPath}/icon-light.svg`,
      logo512: `${brandPath}/icon-light.svg`,
      manifestHref: `${BASE_PATH}/manifest.json`,
    };
  }, []);
}
