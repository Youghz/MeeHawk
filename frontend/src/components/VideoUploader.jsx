import { useState, useRef } from 'react';
import { uploadVideo, uploadYoutube } from '../services/api';

export default function VideoUploader({ onUploaded }) {
  const [uploading, setUploading] = useState(false);
  const [progress, setProgress] = useState(0);
  const [statusText, setStatusText] = useState('');
  const [dragOver, setDragOver] = useState(false);
  const [ytUrl, setYtUrl] = useState('');
  const inputRef = useRef();

  async function handleFile(file) {
    if (!file) return;
    setUploading(true);
    setProgress(0);
    setStatusText('Uploading...');
    try {
      const result = await uploadVideo(file, setProgress);
      onUploaded?.(result.video_id);
    } catch (err) {
      alert('Upload failed: ' + (err.response?.data?.detail || err.message));
    } finally {
      setUploading(false);
      setProgress(0);
      setStatusText('');
    }
  }

  async function handleYoutube(e) {
    e.preventDefault();
    if (!ytUrl.trim()) return;
    setUploading(true);
    setStatusText('Downloading from YouTube...');
    try {
      const result = await uploadYoutube(ytUrl.trim());
      onUploaded?.(result.video_id);
      setYtUrl('');
    } catch (err) {
      alert('YouTube download failed: ' + (err.response?.data?.detail || err.message));
    } finally {
      setUploading(false);
      setStatusText('');
    }
  }

  function onDrop(e) {
    e.preventDefault();
    setDragOver(false);
    handleFile(e.dataTransfer.files[0]);
  }

  return (
    <div className="uploader-container">
      <div
        className={`uploader ${dragOver ? 'drag-over' : ''}`}
        onDragOver={(e) => { e.preventDefault(); setDragOver(true); }}
        onDragLeave={() => setDragOver(false)}
        onDrop={onDrop}
        onClick={() => !uploading && inputRef.current?.click()}
      >
        <input
          ref={inputRef}
          type="file"
          accept="video/*"
          hidden
          onChange={(e) => handleFile(e.target.files[0])}
        />
        {uploading ? (
          <div className="upload-status">
            {progress > 0 && (
              <div className="upload-progress">
                <div className="progress-bar" style={{ width: `${progress}%` }} />
                <span>{progress}%</span>
              </div>
            )}
            <p className="upload-status-text">{statusText}</p>
          </div>
        ) : (
          <p>Drop a video or click to upload</p>
        )}
      </div>

      <form className="yt-form" onSubmit={handleYoutube}>
        <input
          type="text"
          className="yt-input"
          placeholder="YouTube URL"
          value={ytUrl}
          onChange={(e) => setYtUrl(e.target.value)}
          disabled={uploading}
        />
        <button type="submit" className="yt-btn" disabled={uploading || !ytUrl.trim()}>
          DL
        </button>
      </form>
    </div>
  );
}
