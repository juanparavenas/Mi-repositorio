import { Icon, type IconName } from "./Icon";

/** Estado vacío honesto: explica qué falta y cuándo llega, sin contenido simulado. */
export function EmptyState({
  icon = "info",
  title,
  children,
}: {
  icon?: IconName;
  title: string;
  children: React.ReactNode;
}) {
  return (
    <div className="empty-state panel">
      <span className="empty-icon">
        <Icon name={icon} />
      </span>
      <div>
        <h2 className="h3">{title}</h2>
        <div className="empty-body">{children}</div>
      </div>
    </div>
  );
}
