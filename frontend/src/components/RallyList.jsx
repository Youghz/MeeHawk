import { useState, useEffect } from 'react';
import { detectRallies, getRallies, getRallyVideoUrl } from '../services/api';

function formatTime(sec) {
  const m = Math.floor(sec / 60);
  const s = Math.floor(sec % 60);
  return `${m}:${String(s).padStart(2, '0')}`;
}

export default function RallyList({ videoId, onSeek }) {
  const [rallies, setRallies] = useState(null);
  const [detecting, setDetecting] = useState(false);
  const [playingClip, setPlayingClip] = useState(null);

  useEffect(() => {
    if (!videoId) return;
    setRallies(null);
    setPlayingClip(null);
    getRallies(videoId)
      .then((data) => setRallies(data.rallies))
      .catch(() => setRallies(null));
  }, [videoId]);

  async function handleDetect() {
    setDetecting(true);
    try {
      await detectRallies(videoId);
      // Poll until rallies are available
      const poll = setInterval(async () => {
        try {
          const data = await getRallies(videoId);
          if (data.rallies) {
            setRallies(data.rallies);
            clearInterval(poll);
            setDetecting(false);
          }
        } catch { /* still processing */ }
      }, 2000);
    } catch (err) {
      alert('Rally detection failed: ' + (err.response?.data?.detail || err.message));
      setDetecting(false);
    }
  }

  return (
    <div className="rally-panel">
      <div className="rally-header">
        <h4>Rallies</h4>
        <button
          className="rally-detect-btn"
          onClick={handleDetect}
          disabled={detecting}
        >
          {detecting ? 'Detecting...' : rallies ? 'Re-detect' : 'Detect'}
        </button>
      </div>

      {detecting && <p className="rally-hint">Analyzing player movement...</p>}

      {rallies && rallies.length === 0 && !detecting && (
        <p className="rally-hint">No rallies detected.</p>
      )}

      {rallies && rallies.length > 0 && (
        <ul className="rally-list">
          {rallies.map((r) => (
            <li key={r.rally_id} className="rally-item">
              <button
                className="rally-seek"
                title="Seek to rally"
                onClick={() => { onSeek?.(r.padded_start_time); setPlayingClip(null); }}
              >
                Rally {r.rally_id}
              </button>
              <span className="rally-time">
                {formatTime(r.start_time)} - {formatTime(r.end_time)}
              </span>
              <span className="rally-duration">{r.duration}s</span>
              <a
                className="rally-clip-link"
                href={getRallyVideoUrl(videoId, r.rally_id)}
                target="_blank"
                rel="noreferrer"
                title="Open clip"
              >
                {'\u21E5'}
              </a>
            </li>
          ))}
        </ul>
      )}

      {!rallies && !detecting && (
        <p className="rally-hint">Click "Detect" to find rallies from tracking data.</p>
      )}
    </div>
  );
}
