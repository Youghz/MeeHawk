import { useState, useCallback, useRef } from 'react';
import VideoPlayer from './VideoPlayer';
import CourtView from './CourtView';
import RallyList from './RallyList';
import { computeHomography, applyHomography, COURT_CORNERS_M } from '../utils/homography';

const COLORS = [
  '#58a6ff', '#f0883e', '#a371f7', '#3fb950', '#f85149',
  '#d29922', '#db61a2', '#79c0ff', '#7ee787', '#ffa657',
];

function getColor(id) {
  return COLORS[id % COLORS.length];
}

export default function AnalysisView({ videoId }) {
  const [courtPoints, setCourtPoints] = useState(null);
  const [calibrating, setCalibrating] = useState(false);
  const [calibPts, setCalibPts] = useState([]);
  const [players, setPlayers] = useState([]);
  const homographyRef = useRef(null);
  const seekRef = useRef(null); // function to seek the video player

  const handleFrameDetections = useCallback(
    (detections, videoW, videoH) => {
      if (!homographyRef.current || !detections.length) {
        setPlayers([]);
        return;
      }
      const H = homographyRef.current;
      const pts = [];
      for (const det of detections) {
        const [x1, y1, x2, y2] = det.bbox;
        const footX = (x1 + x2) / 2;
        const footY = y2;
        const projected = applyHomography(H, footX, footY);
        if (projected) {
          pts.push({
            id: det.tracker_id,
            x: projected[0],
            y: projected[1],
            color: getColor(det.tracker_id),
          });
        }
      }
      setPlayers(pts);
    },
    []
  );

  function startCalibration() {
    setCalibrating(true);
    setCalibPts([]);
    setCourtPoints(null);
    homographyRef.current = null;
  }

  function handleCalibClick(e) {
    if (!calibrating) return;
    const video = e.target.closest('.player-viewport')?.querySelector('video');
    if (!video) return;

    const rect = video.getBoundingClientRect();
    const scaleX = video.videoWidth / rect.width;
    const scaleY = video.videoHeight / rect.height;
    const px = (e.clientX - rect.left) * scaleX;
    const py = (e.clientY - rect.top) * scaleY;

    const next = [...calibPts, [px, py]];
    setCalibPts(next);

    if (next.length === 4) {
      const H = computeHomography(next, COURT_CORNERS_M);
      homographyRef.current = H;
      setCourtPoints(next);
      setCalibrating(false);
    }
  }

  function handleSeek(timeSeconds) {
    seekRef.current?.(timeSeconds);
  }

  const CORNER_LABELS = ['Top-Left', 'Top-Right', 'Bottom-Right', 'Bottom-Left'];

  return (
    <div className="analysis-view">
      <div className="analysis-main" onClick={calibrating ? handleCalibClick : undefined}>
        <VideoPlayer
          videoId={videoId}
          onFrameDetections={handleFrameDetections}
          seekRef={seekRef}
        />
      </div>

      <div className="analysis-side">
        <div className="court-panel">
          <div className="court-header">
            <h4>Court View</h4>
            <button
              className={`calib-btn ${calibrating ? 'active' : ''}`}
              onClick={startCalibration}
            >
              {calibrating ? 'Calibrating...' : courtPoints ? 'Recalibrate' : 'Calibrate'}
            </button>
          </div>

          {calibrating && (
            <p className="calib-hint">
              Click corner <strong>{CORNER_LABELS[calibPts.length]}</strong> of the court
              ({calibPts.length}/4)
            </p>
          )}

          {!courtPoints && !calibrating && (
            <p className="calib-hint">
              Click "Calibrate" to enable the top-down court view.
            </p>
          )}

          <CourtView players={players} width={220} />
        </div>

        <RallyList videoId={videoId} onSeek={handleSeek} />
      </div>
    </div>
  );
}
