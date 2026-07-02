import { useCallback, useEffect, useRef, useState } from 'react';
import { CheckCircle2, Loader2, Upload, AlertCircle } from 'lucide-react';
import api from '../../api/axios';

function formatPhase(phase) {
  if (!phase) return 'Starting…';
  const map = {
    queued: 'Queued…',
    parsing: 'Reading your export…',
    mapping_tv: 'Matching TV shows…',
    mapping_movies: 'Matching films…',
    clearing: 'Replacing your diary…',
    writing_tv: 'Importing episodes…',
    writing_movies: 'Importing films…',
    writing_lists: 'Importing lists…',
    done: 'Complete',
    failed: 'Failed',
  };
  if (map[phase.split(' ')[0]]) return phase.includes('(') ? phase.replace(/_/g, ' ') : map[phase.split(' ')[0]];
  return phase.replace(/_/g, ' ');
}

export default function TvTimeImportSection() {
  const [job, setJob] = useState(null);
  const [loading, setLoading] = useState(true);
  const [uploading, setUploading] = useState(false);
  const [uploadError, setUploadError] = useState('');
  const [allowNewImport, setAllowNewImport] = useState(false);
  const fileRef = useRef(null);

  const fetchStatus = useCallback(() => {
    return api.get('/api/import/tvtime/status').then((r) => {
      if (r.data.success) setJob(r.data.job);
      return r.data.job;
    });
  }, []);

  useEffect(() => {
    fetchStatus().finally(() => setLoading(false));
  }, [fetchStatus]);

  useEffect(() => {
    if (!job || !['queued', 'processing'].includes(job.status)) return undefined;
    const id = setInterval(fetchStatus, 5000);
    return () => clearInterval(id);
  }, [job, fetchStatus]);

  const onUpload = async (e) => {
    e.preventDefault();
    const file = fileRef.current?.files?.[0];
    if (!file) {
      setUploadError('Choose your TV Time export .zip file.');
      return;
    }
    if (!file.name.toLowerCase().endsWith('.zip')) {
      setUploadError('Upload must be a .zip file.');
      return;
    }

    setUploadError('');
    setUploading(true);
    try {
      const form = new FormData();
      form.append('file', file);
      const r = await api.post('/api/import/tvtime', form, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });
      if (r.data.success) {
        setJob(r.data.job);
        setAllowNewImport(false);
        if (fileRef.current) fileRef.current.value = '';
      }
    } catch (err) {
      setUploadError(
        err.response?.data?.message || 'Upload failed. Try again or use a smaller export zip.'
      );
      if (err.response?.data?.job) setJob(err.response.data.job);
    } finally {
      setUploading(false);
    }
  };

  const isActive = job && ['queued', 'processing'].includes(job.status);
  const isDone = job?.status === 'completed' && !allowNewImport;
  const isFailed = job?.status === 'failed' && !allowNewImport;
  const showUploadForm = !loading && !isActive && (!job || allowNewImport || isFailed);
  const report = job?.report;

  return (
    <section className="glass-card p-5 sm:p-6">
      <h2 className="section-title mb-2 normal-case tracking-wide">Import from TV Time</h2>
      <p className="mb-4 text-sm text-muted">
        Upload the GDPR export zip from TV Time. We&apos;ll replace your Marquee diary with that
        data — episodes, films, favorites, and watchlists. Usually takes 5–15 minutes; you can leave
        and come back here to check progress.
      </p>

      <ol className="mb-5 list-decimal space-y-1 pl-4 text-xs text-muted">
        <li>In TV Time: Settings → Privacy → Request my data</li>
        <li>Download the zip when it arrives and upload it below</li>
      </ol>

      {loading ? (
        <div className="flex items-center gap-2 text-sm text-muted">
          <Loader2 className="h-4 w-4 animate-spin" />
          Checking import status…
        </div>
      ) : isActive ? (
        <div className="rounded-xl border border-accent/30 bg-accent/10 px-4 py-4">
          <div className="flex items-start gap-3">
            <Loader2 className="mt-0.5 h-5 w-5 shrink-0 animate-spin text-accent" />
            <div>
              <p className="font-semibold text-ink-bright">Import in progress</p>
              <p className="mt-1 text-sm text-muted">{formatPhase(job.phase)}</p>
              <p className="mt-2 text-xs text-muted">
                You can close this page — we&apos;ll keep working. Check back here for results.
              </p>
            </div>
          </div>
        </div>
      ) : showUploadForm ? (
        <form onSubmit={onUpload} className="space-y-3">
          <label className="flex cursor-pointer flex-col items-center justify-center rounded-xl border-2 border-dashed border-border bg-surface/50 px-4 py-8 transition-colors hover:border-accent/40 hover:bg-accent/5">
            <Upload className="mb-2 h-8 w-8 text-muted" />
            <span className="text-sm font-medium text-ink">Choose TV Time export .zip</span>
            <span className="mt-1 text-xs text-muted">Max 50 MB · replaces your current diary</span>
            <input
              ref={fileRef}
              type="file"
              accept=".zip,application/zip"
              className="sr-only"
              disabled={uploading}
            />
          </label>
          {uploadError && (
            <p className="flex items-start gap-2 text-sm text-red-400">
              <AlertCircle className="mt-0.5 h-4 w-4 shrink-0" />
              {uploadError}
            </p>
          )}
          <button type="submit" disabled={uploading} className="btn-primary w-full sm:w-auto">
            {uploading ? 'Uploading…' : 'Start import'}
          </button>
        </form>
      ) : null}

      {isDone && report && (
        <div className="mt-5 rounded-xl border border-border bg-surface/50 px-4 py-4">
          <div className="flex items-start gap-2">
            <CheckCircle2 className="mt-0.5 h-5 w-5 shrink-0 text-accent" />
            <div className="min-w-0">
              <p className="font-semibold text-ink-bright">Import complete</p>
              <ul className="mt-2 space-y-1 text-sm text-muted">
                <li>{report.tv?.episodesImported ?? 0} TV episodes</li>
                <li>{report.tv?.shows ?? 0} shows tracked</li>
                <li>{report.movies?.watchedMapped ?? 0} films watched</li>
                <li>{report.movies?.favoritesMapped ?? 0} favorite films</li>
                <li>{report.tv?.favorites ?? 0} favorite TV shows</li>
                <li>{report.tv?.watchlist ?? 0} TV watchlist · {report.movies?.towatchMapped ?? 0} film watchlist</li>
              </ul>
              {(report.tv?.unmapped?.length > 0 || report.movies?.watchedUnmapped?.length > 0) && (
                <p className="mt-3 text-xs text-muted">
                  Some titles couldn&apos;t be matched to TMDB (
                  {(report.tv?.unmapped?.length || 0) + (report.movies?.watchedUnmapped?.length || 0)}{' '}
                  skipped). Your CLI report has details if you need them.
                </p>
              )}
              {!isActive && (
                <button
                  type="button"
                  className="btn-secondary mt-4 !text-xs"
                  onClick={() => setAllowNewImport(true)}
                >
                  Import another export
                </button>
              )}
            </div>
          </div>
        </div>
      )}

      {isFailed && (
        <div className="mt-5 rounded-xl border border-red-400/30 bg-red-400/10 px-4 py-4">
          <div className="flex items-start gap-2">
            <AlertCircle className="mt-0.5 h-5 w-5 shrink-0 text-red-400" />
            <div>
              <p className="font-semibold text-ink-bright">Import failed</p>
              <p className="mt-1 text-sm text-muted">{job.errorMessage || 'Something went wrong.'}</p>
              <button
                type="button"
                className="btn-secondary mt-3 !text-xs"
                onClick={() => setAllowNewImport(true)}
              >
                Try again
              </button>
            </div>
          </div>
        </div>
      )}
    </section>
  );
}
