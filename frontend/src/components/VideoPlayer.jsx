import { useEffect, useRef, useState, useCallback } from 'react';
import { getSourceVideoUrl, getTrackingData, saveFrameCorrection } from '../services/api';

const COLORS = [
  '#58a6ff', '#f0883e', '#a371f7', '#3fb950', '#f85149',
  '#d29922', '#db61a2', '#79c0ff', '#7ee787', '#ffa657',
];

function getColor(trackerId) {
  return COLORS[trackerId % COLORS.length];
}

export default function VideoPlayer({ videoId, onFrameDetections, seekRef }) {
  const videoRef = useRef(null);
  const canvasRef = useRef(null);
  const wrapperRef = useRef(null);
  const animRef = useRef(null);

  const [tracking, setTracking] = useState(null);
  const [showAnnotations, setShowAnnotations] = useState(true);
  const [loading, setLoading] = useState(true);
  const [editMode, setEditMode] = useState(false);
  const [selectedDet, setSelectedDet] = useState(null);
  const [currentFrame, setCurrentFrame] = useState(0);

  // Zoom & pan state
  const [zoom, setZoom] = useState(1);
  const [pan, setPan] = useState({ x: 0, y: 0 });
  const isPanning = useRef(false);
  const panStart = useRef({ x: 0, y: 0 });

  // Load tracking data
  const loadTracking = useCallback(() => {
    if (!videoId) return;
    setLoading(true);
    getTrackingData(videoId)
      .then(setTracking)
      .catch(() => setTracking(null))
      .finally(() => setLoading(false));
  }, [videoId]);

  useEffect(() => {
    loadTracking();
    setZoom(1);
    setPan({ x: 0, y: 0 });
  }, [loadTracking]);

  // Expose seek function to parent via ref
  useEffect(() => {
    if (seekRef) {
      seekRef.current = (timeSeconds) => {
        if (videoRef.current) {
          videoRef.current.currentTime = timeSeconds;
          videoRef.current.play();
        }
      };
    }
  }, [seekRef]);

  // Build lookup: frame_number -> detections
  const frameMap = useRef({});
  useEffect(() => {
    if (!tracking) return;
    const map = {};
    for (const frame of tracking.frames) {
      map[frame.frame_number] = frame.detections;
    }
    frameMap.current = map;
  }, [tracking]);

  function getFrameDetections() {
    if (!tracking) return [];
    const fn = Math.round((videoRef.current?.currentTime || 0) * tracking.fps);
    return frameMap.current[fn] || [];
  }

  // --- Drawing ---
  useEffect(() => {
    const video = videoRef.current;
    const canvas = canvasRef.current;
    if (!video || !canvas || !tracking) return;

    const ctx = canvas.getContext('2d');
    const fps = tracking.fps;

    function draw() {
      const ct = video.currentTime;
      const fn = Math.round(ct * fps);
      setCurrentFrame(fn);

      const rect = video.getBoundingClientRect();
      canvas.width = rect.width;
      canvas.height = rect.height;
      ctx.clearRect(0, 0, canvas.width, canvas.height);

      if (!showAnnotations || !video.videoWidth) {
        animRef.current = requestAnimationFrame(draw);
        return;
      }

      const detections = frameMap.current[fn];
      if (onFrameDetections) {
        onFrameDetections(detections || [], video.videoWidth, video.videoHeight);
      }
      if (!detections) {
        animRef.current = requestAnimationFrame(draw);
        return;
      }

      const scaleX = rect.width / video.videoWidth;
      const scaleY = rect.height / video.videoHeight;

      for (const det of detections) {
        const [x1, y1, x2, y2] = det.bbox;
        const sx = x1 * scaleX;
        const sy = y1 * scaleY;
        const sw = (x2 - x1) * scaleX;
        const sh = (y2 - y1) * scaleY;
        const color = getColor(det.tracker_id);
        const isSelected = editMode && selectedDet?.tracker_id === det.tracker_id;

        ctx.strokeStyle = isSelected ? '#fff' : color;
        ctx.lineWidth = isSelected ? 3 : 2;
        ctx.strokeRect(sx, sy, sw, sh);

        const label = `#${det.tracker_id}`;
        ctx.font = 'bold 14px sans-serif';
        const tw = ctx.measureText(label).width;
        const lh = 20;
        ctx.fillStyle = isSelected ? '#fff' : color;
        ctx.fillRect(sx, sy - lh, tw + 8, lh);
        ctx.fillStyle = isSelected ? '#000' : '#fff';
        ctx.fillText(label, sx + 4, sy - 5);
      }

      if (editMode) {
        ctx.fillStyle = 'rgba(249, 80, 73, 0.8)';
        ctx.fillRect(0, 0, 90, 24);
        ctx.fillStyle = '#fff';
        ctx.font = 'bold 12px sans-serif';
        ctx.fillText('EDIT MODE', 8, 16);
      }

      if (zoom > 1) {
        ctx.fillStyle = 'rgba(0,0,0,0.5)';
        ctx.fillRect(canvas.width - 60, 0, 60, 24);
        ctx.fillStyle = '#fff';
        ctx.font = 'bold 12px sans-serif';
        ctx.fillText(`${zoom.toFixed(1)}x`, canvas.width - 52, 16);
      }

      animRef.current = requestAnimationFrame(draw);
    }

    draw();
    return () => cancelAnimationFrame(animRef.current);
  }, [tracking, showAnnotations, editMode, selectedDet, zoom]);

  // --- Click to select detection ---
  // When overlapping, pick the SMALLEST bbox (most precise)
  function handleCanvasClick(e) {
    if (!editMode || !tracking || !videoRef.current) return;
    if (isPanning.current) return;

    const video = videoRef.current;
    const rect = video.getBoundingClientRect();
    const clickX = e.clientX - rect.left;
    const clickY = e.clientY - rect.top;
    const scaleX = rect.width / video.videoWidth;
    const scaleY = rect.height / video.videoHeight;

    const dets = getFrameDetections();
    let best = null;
    let bestArea = Infinity;

    for (const det of dets) {
      const [x1, y1, x2, y2] = det.bbox;
      const sx = x1 * scaleX;
      const sy = y1 * scaleY;
      const sw = (x2 - x1) * scaleX;
      const sh = (y2 - y1) * scaleY;
      if (clickX >= sx && clickX <= sx + sw && clickY >= sy && clickY <= sy + sh) {
        const area = sw * sh;
        if (area < bestArea) {
          bestArea = area;
          best = det;
        }
      }
    }
    setSelectedDet(best);
  }

  // --- Zoom (scroll wheel) ---
  function handleWheel(e) {
    if (!editMode) return;
    e.preventDefault();
    const delta = e.deltaY > 0 ? -0.25 : 0.25;
    setZoom((z) => {
      const next = Math.max(1, Math.min(5, z + delta));
      if (next === 1) setPan({ x: 0, y: 0 });
      return next;
    });
  }

  // --- Pan (middle-click drag or shift+drag) ---
  function handleMouseDown(e) {
    if (!editMode || zoom <= 1) return;
    if (e.button === 1 || e.shiftKey) {
      e.preventDefault();
      isPanning.current = true;
      panStart.current = { x: e.clientX - pan.x, y: e.clientY - pan.y };
    }
  }

  function handleMouseMove(e) {
    if (!isPanning.current) return;
    setPan({
      x: e.clientX - panStart.current.x,
      y: e.clientY - panStart.current.y,
    });
  }

  function handleMouseUp() {
    isPanning.current = false;
  }

  // --- Frame stepping ---
  function stepFrame(delta) {
    const video = videoRef.current;
    if (!video || !tracking) return;
    video.currentTime = Math.max(0, video.currentTime + delta / tracking.fps);
  }

  // --- Corrections ---
  async function handleSwapId() {
    if (!selectedDet) return;
    const newId = prompt(`Change tracker #${selectedDet.tracker_id} to which ID?`);
    if (newId === null) return;
    const parsed = parseInt(newId, 10);
    if (isNaN(parsed)) return;
    await saveFrameCorrection(videoId, {
      frame_number: currentFrame,
      id_swaps: { [selectedDet.tracker_id]: parsed },
      removed_ids: [],
    });
    setSelectedDet(null);
    loadTracking();
  }

  async function handleRemove() {
    if (!selectedDet) return;
    await saveFrameCorrection(videoId, {
      frame_number: currentFrame,
      id_swaps: {},
      removed_ids: [selectedDet.tracker_id],
    });
    setSelectedDet(null);
    loadTracking();
  }

  function resetZoom() {
    setZoom(1);
    setPan({ x: 0, y: 0 });
  }

  if (!videoId) return null;

  const transformStyle = editMode && zoom > 1
    ? { transform: `scale(${zoom}) translate(${pan.x / zoom}px, ${pan.y / zoom}px)`, transformOrigin: 'center center' }
    : {};

  return (
    <div className="video-player">
      <div className="player-header">
        <h3>Annotated Video</h3>
        <div className="player-controls">
          <label className="toggle-annotations">
            <input
              type="checkbox"
              checked={showAnnotations}
              onChange={(e) => setShowAnnotations(e.target.checked)}
            />
            Annotations
          </label>
          <button
            className={`edit-btn ${editMode ? 'active' : ''}`}
            onClick={() => {
              setEditMode(!editMode);
              setSelectedDet(null);
              resetZoom();
            }}
          >
            {editMode ? 'Exit edit' : 'Edit'}
          </button>
        </div>
      </div>

      {loading && <p className="loading-msg">Loading tracking data...</p>}

      {/* Video + canvas wrapper — zoom/pan applies here, controls stay outside */}
      <div
        className="player-viewport"
        onWheel={handleWheel}
        onMouseDown={handleMouseDown}
        onMouseMove={handleMouseMove}
        onMouseUp={handleMouseUp}
        onMouseLeave={handleMouseUp}
      >
        <div ref={wrapperRef} className="player-wrapper" style={transformStyle}>
          <video
            ref={videoRef}
            key={videoId}
            controls={!editMode}
            preload="metadata"
            width="100%"
            src={getSourceVideoUrl(videoId)}
          />
          <canvas
            ref={canvasRef}
            className={`annotation-canvas ${editMode ? 'editable' : ''}`}
            onClick={handleCanvasClick}
          />
        </div>
      </div>

      {/* Edit toolbar with frame scrubber */}
      {editMode && (
        <div className="edit-panel">
          <div className="edit-scrubber">
            <button className="step-btn" onClick={() => stepFrame(-1)}>{'<'}</button>
            <input
              type="range"
              className="frame-slider"
              min={0}
              max={tracking ? (tracking.total_frames - 1) : 0}
              value={currentFrame}
              onChange={(e) => {
                const fn = parseInt(e.target.value, 10);
                if (videoRef.current && tracking) {
                  videoRef.current.currentTime = fn / tracking.fps;
                }
              }}
            />
            <button className="step-btn" onClick={() => stepFrame(1)}>{'>'}</button>
            <span className="edit-frame">Frame {currentFrame}</span>
          </div>
          <div className="edit-toolbar">
            {zoom > 1 && (
              <button className="zoom-reset" onClick={resetZoom}>Reset zoom</button>
            )}
            {selectedDet ? (
              <>
                <span className="edit-selected">Selected: #{selectedDet.tracker_id}</span>
                <button onClick={handleSwapId}>Change ID</button>
                <button className="remove-btn" onClick={handleRemove}>Remove</button>
              </>
            ) : (
              <span className="edit-hint">
                Click a detection | Scroll to zoom | Shift+drag to pan
              </span>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
