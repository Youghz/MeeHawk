import { deleteVideo, clearAnnotations, analyzeVideo, detectRallies, cancelProcessing } from '../services/api';

export default function VideoLibrary({ videos, jobs = [], selectedId, onSelect, onRefresh, onDelete }) {
  function getJob(videoId) {
    return jobs.find((j) => j.video_id === videoId && j.status === 'running');
  }

  // Separate root videos and children
  const roots = videos.filter((v) => !v.parent_id);
  const childrenOf = (parentId) => videos.filter((v) => v.parent_id === parentId);

  function renderItem(v, isChild = false) {
    const isActive = v.video_id === selectedId;
    const job = getJob(v.video_id);
    const isProcessing = v.status === 'processing';
    const hasJob = !!job;
    const showActions = isActive && !isProcessing && !hasJob;

    return (
      <li
        key={v.video_id}
        className={`library-item ${isActive ? 'active' : ''} ${isChild ? 'child' : ''}`}
        onClick={() => onSelect(v.video_id)}
      >
        {isChild && <span className="tree-indent">{'\u2514'}</span>}
        <span className={`status-dot ${v.status}`} />
        <span className="library-name">{v.original_name}</span>

        {isProcessing && v.progress && (
          <span className="library-progress-info">
            <span className="library-percent">{v.progress.percent}%</span>
          </span>
        )}

        {hasJob && job.progress && (
          <span className="library-progress-info">
            <span className="library-step">
              {job.progress.step === 'detecting' ? 'Detecting' : 'Splitting'}
            </span>
            <span className="library-percent">{job.progress.percent}%</span>
          </span>
        )}

        {(isProcessing || hasJob) && isActive && (
          <button
            className="action-cancel-pill"
            title="Cancel"
            onClick={async (e) => {
              e.stopPropagation();
              await cancelProcessing(v.video_id);
              onRefresh?.();
            }}
          >{'\u25A0'}</button>
        )}

        {showActions && (
          <span className="library-inline-actions" onClick={(e) => e.stopPropagation()}>
            {!isChild && (v.status === 'pending' || v.status === 'completed') && (
              <button
                className="action-pill action-track"
                title="Player Detection & Tracking"
                onClick={async () => { await analyzeVideo(v.video_id); onRefresh?.(); }}
              >Track</button>
            )}
            {!isChild && (v.status === 'pending' || v.status === 'completed') && (
              <button
                className="action-pill action-rally"
                title="Split into Rallies"
                onClick={async () => { await detectRallies(v.video_id); onRefresh?.(); }}
              >Split</button>
            )}
            {isChild && v.status === 'pending' && (
              <button
                className="action-pill action-track"
                title="Player Detection & Tracking"
                onClick={async () => { await analyzeVideo(v.video_id); onRefresh?.(); }}
              >Track</button>
            )}
            {v.status === 'completed' && (
              <button
                className="action-pill action-clear"
                title="Clear annotations"
                onClick={async () => {
                  if (!confirm('Clear annotations?')) return;
                  await clearAnnotations(v.video_id); onRefresh?.();
                }}
              >{'\u21BA'}</button>
            )}
            <button
              className="action-pill action-delete"
              title="Delete"
              onClick={async () => {
                if (!confirm(`Delete "${v.original_name}"?`)) return;
                await deleteVideo(v.video_id); onDelete?.(v.video_id);
              }}
            >{'\u2715'}</button>
          </span>
        )}
      </li>
    );
  }

  return (
    <div className="library">
      <h3 className="library-heading">Videos</h3>

      {videos.length === 0 ? (
        <p className="library-empty">No videos yet.</p>
      ) : (
        <ul className="library-list">
          {roots.map((v) => (
            <div key={v.video_id} className="library-group">
              {renderItem(v, false)}
              {childrenOf(v.video_id).map((child) => renderItem(child, true))}
            </div>
          ))}
        </ul>
      )}
    </div>
  );
}
