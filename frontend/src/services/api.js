import axios from 'axios';

const api = axios.create({ baseURL: '/api' });

export async function uploadVideo(file, onProgress) {
  const form = new FormData();
  form.append('file', file);
  const { data } = await api.post('/videos/upload', form, {
    onUploadProgress: (e) => onProgress?.(Math.round((e.loaded * 100) / e.total)),
  });
  return data;
}

export async function uploadYoutube(url) {
  const { data } = await api.post('/videos/upload/youtube', { url });
  return data;
}

export async function getVideos() {
  const { data } = await api.get('/videos');
  return data.videos;
}

export async function getVideo(videoId) {
  const { data } = await api.get(`/videos/${videoId}`);
  return data;
}

export async function analyzeVideo(videoId) {
  const { data } = await api.post(`/videos/${videoId}/analyze`);
  return data;
}

export async function cancelProcessing(videoId) {
  const { data } = await api.post(`/videos/${videoId}/cancel`);
  return data;
}

export function getSourceVideoUrl(videoId) {
  return `/api/videos/${videoId}/source`;
}

export async function getTrackingData(videoId) {
  const { data } = await api.get(`/videos/${videoId}/result/data`);
  return data;
}

export async function deleteVideo(videoId) {
  const { data } = await api.delete(`/videos/${videoId}`);
  return data;
}

export async function clearAnnotations(videoId) {
  const { data } = await api.delete(`/videos/${videoId}/annotations`);
  return data;
}

// --- Manual corrections ---

export async function getCorrections(videoId) {
  const { data } = await api.get(`/videos/${videoId}/corrections`);
  return data;
}

export async function saveFrameCorrection(videoId, correction) {
  const { data } = await api.post(`/videos/${videoId}/corrections/frame`, correction);
  return data;
}

export async function deleteFrameCorrection(videoId, frameNumber) {
  const { data } = await api.delete(`/videos/${videoId}/corrections/${frameNumber}`);
  return data;
}

// --- Rallies ---

export async function detectRallies(videoId, config = {}) {
  const { data } = await api.post(`/videos/${videoId}/detect-rallies`, config);
  return data;
}

export async function getActiveJobs() {
  const { data } = await api.get('/videos/jobs/active');
  return data.jobs;
}

export async function getRallies(videoId) {
  const { data } = await api.get(`/videos/${videoId}/rallies`);
  return data;
}

export function getRallyVideoUrl(videoId, rallyId) {
  return `/api/videos/${videoId}/rallies/${rallyId}/video`;
}
