import { BASE_PATH } from "@app/constants/app";
import "@app/components/shared/BrandMark.css";
interface BrandMarkProps { height?: string; className?: string; }
/** The PDF_Tunner identity mark keeps the original app-switch dropdown cue. */
export function BrandMark({ height = "1.6rem", className }: BrandMarkProps) {
  return (
    <span className={`sui-brandmark${className ? ` ${className}` : ""}`}
      style={{ height, width: height }} aria-hidden="true">
      <img className="sui-brandmark__icon"
        src={`${BASE_PATH}/pdf-tunner/icon-light.svg`} alt="" />
      <span className="sui-brandmark__chevron">⌄</span>
    </span>
  );
}
