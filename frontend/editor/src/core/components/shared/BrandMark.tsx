import { BASE_PATH } from "@app/constants/app";
import "@app/components/shared/BrandMark.css";

interface BrandMarkProps {
  height?: string;
  className?: string;
}

/** Shared PDF_Tunner mark for the editor/processor switch control. */
export function BrandMark({ height = "1.6rem", className }: BrandMarkProps) {
  return (
    <img
      className={`sui-brandmark${className ? ` ${className}` : ""}`}
      src={`${BASE_PATH}/pdf-tunner/icon-light.svg`}
      alt="PDF_Tunner"
      style={{ height }}
    />
  );
}
