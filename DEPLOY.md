# Deploy Marquee (Vercel + Render)

Free-tier setup for sharing with friends: **React on Vercel**, **API on Render**, **MongoDB Atlas**.

## 1. MongoDB Atlas (database)

1. Create a free **M0** cluster at [mongodb.com/cloud/atlas](https://www.mongodb.com/cloud/atlas).
2. Database name in URI: `...mongodb.net/showtracker?...`
3. Network access: allow `0.0.0.0/0` (or Render’s IPs if you restrict later).
4. Copy the connection string for `MONGODB_URI`.

## 2. Render (backend API)

1. Push this repo to GitHub.
2. [render.com](https://render.com) → **New → Blueprint** (uses `render.yaml`)  
   **or** **New → Web Service** with:
   - **Root directory:** `backend-server`
   - **Build command:** `npm install`
   - **Start command:** `node bin/www`
   - **Health check path:** `/health`
3. Environment variables:

| Variable | Example |
|----------|---------|
| `MONGODB_URI` | `mongodb+srv://...` |
| `JWT_SECRET` | long random string |
| `TMDB_API_KEY` | from themoviedb.org |
| `GOOGLE_CLIENT_ID` | same as frontend |
| `CORS_ORIGINS` | `https://your-app.vercel.app` |

4. Note your API URL, e.g. `https://marquee-api.onrender.com`.

**Free tier:** service sleeps after ~15 min idle; first request may take **30–60 seconds** to wake.

## 3. Vercel (frontend)

1. [vercel.com](https://vercel.com) → **Import** GitHub repo.
2. **Root directory:** `main-folder`
3. Framework: Create React App (auto-detected).
4. Environment variables (Production):

| Variable | Value |
|----------|--------|
| `REACT_APP_API_URL` | `https://marquee-api.onrender.com` |
| `REACT_APP_TMDB_API_KEY` | your TMDB key |
| `REACT_APP_GOOGLE_CLIENT_ID` | your Google OAuth client ID |

5. Deploy. Note URL, e.g. `https://marquee.vercel.app`.

6. Back on **Render**, set `CORS_ORIGINS` to your Vercel URL (redeploy if needed).

## 4. Google OAuth

In [Google Cloud Console](https://console.cloud.google.com/apis/credentials):

- **Authorized JavaScript origins:**  
  `http://localhost:3000`  
  `https://your-app.vercel.app`
- Use **External** app type; **Testing** mode + add friends as **Test users** (up to 100).

## 5. Verify

- `https://marquee-api.onrender.com/health` → `{ "ok": true }`
- Open Vercel URL → sign up / sign in
- Settings → TV Time import (optional)

## Local development

Unchanged: from `backend-server`, run `npm start` (API + React).  
Use `main-folder/.env.development` and `backend-server/.env` for local URLs.
