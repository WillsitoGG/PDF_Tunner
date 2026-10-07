import { useMemo } from "react";
import { BASE_PATH } from "@app/constants/app";
import { getLogoFolder } from "@app/constants/logo";
import { useLogoVariant } from "@app/hooks/useLogoVariant";

export function useLogoAssets() {
  const logoVariant = useLogoVariant();

  return useMemo(() => {
    const folder = getLogoFolder(logoVariant);
    const folderPath = `${BASE_PATH}/${folder}`;
    const pdfTunnerBrandPath = `${BASE_PATH}/pdf-tunner`;

    return {
      logoVariant,
      folder,
      folderPath,
      getAssetPath: (name: string) => `${folderPath}/${name}`,
      wordmark: {
        black: `${pdfTunnerBrandPath}/wordmark-black.svg`,
        grey: `${pdfTunnerBrandPath}/wordmark-grey.svg`,
        white: `${pdfTunnerBrandPath}/wordmark-white.svg`,
      },
      tooltipLogo: `${pdfTunnerBrandPath}/icon-light.svg`,
      firstPage: `${folderPath}/Firstpage.png`,
      favicon: `${pdfTunnerBrandPath}/icon-light.svg`,
      logo192: `${pdfTunnerBrandPath}/icon-light.svg`,
      logo512: `${pdfTunnerBrandPath}/icon-light.svg`,
      manifestHref:
        logoVariant === "classic"
          ? `${BASE_PATH}/manifest-classic.json`
          : `${BASE_PATH}/manifest.json`,
    };
  }, [logoVariant]);
}
