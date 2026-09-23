interface Props {
  kind?: "loading" | "error" | "empty";
  children: React.ReactNode;
  retry?: () => void;
}

export function StatusMessage({ kind = "empty", children, retry }: Props) {
  return (
    <div className={`state-message ${kind}`} role={kind === "error" ? "alert" : "status"}>
      <span className="state-icon" aria-hidden="true">{kind === "loading" ? "···" : kind === "error" ? "!" : "○"}</span>
      <div>
        <p>{children}</p>
        {retry && <button className="text-button" type="button" onClick={retry}>Try again</button>}
      </div>
    </div>
  );
}
