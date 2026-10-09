import { BASE_PATH } from "@app/constants/app";
import "@app/components/shared/BrandMark.css";

interface BrandMarkProps {
  height?: string;
  className?: string;
}

/** Branded app-switch logo. Preserve the menu chevron instead of showing Stirling. */
export function BrandMark({ height = "1.6rem", className }: BrandMarkProps) {
  return (
    <span
      className={`sui-brandmark${className ? ` ${className}` : ""}`}
      style={{ height, width: height }}
      aria-label="PDF_Tunner"
    >
      <img
        className="sui-brandmark__icon"
        src={`${BASE_PATH}/pdf-tunner/icon-light.svg`}
        alt=""
        aria-hidden="true"
      />
      <span className="sui-brandmark__chevron" aria-hidden="true">⌄</span>
    </span>
  );
}
