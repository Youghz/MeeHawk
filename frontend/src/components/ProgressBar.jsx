function formatTime(seconds) {
  if (!seconds || seconds < 0) return '--:--';
  if (seconds >= 3600) {
    const h = Math.floor(seconds / 3600);
    const m = Math.floor((seconds % 3600) / 60);
    const s = Math.floor(seconds % 60);
    return `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  }
  const m = Math.floor(seconds / 60);
  const s = Math.floor(seconds % 60);
  return `${m}:${String(s).padStart(2, '0')}`;
}

export default function ProgressBar({ progress, name }) {
  if (!progress) {
    return (
      <div className="progress-container">
        <p className="progress-waiting">Starting analysis...</p>
      </div>
    );
  }

  const { current_frame, total_frames, elapsed_seconds, estimated_remaining_seconds, percent } = progress;

  return (
    <div className="progress-container">
      {name && <p className="progress-name">{name}</p>}
      <div className="progress-eta-block">
        <span className="eta-label">Estimated time remaining</span>
        <span className="eta-value">{formatTime(estimated_remaining_seconds)}</span>
      </div>
      <div className="progress-track">
        <div className="progress-fill" style={{ width: `${percent}%` }} />
      </div>
      <div className="progress-details">
        <span className="progress-percent">{percent}%</span>
        <span className="progress-frames">{current_frame} / {total_frames} frames</span>
        <span className="progress-elapsed">Elapsed {formatTime(elapsed_seconds)}</span>
      </div>
    </div>
  );
}
