# Movies and TV Show Tracker

## I've noted some rules to follow when you're coding and commiting on Github

- To start the project just go to backend-server and do `npm start`. It'll run both `client(main-folder)` and `server(backend-server)`.

- Client is on `localhost:3000` and the API on `localhost:5001` (set in `backend-server/.env` as `PORT=5001`).

- macOS reserves port **5000** for AirPlay Receiver (`ControlCenter`) — that is not this app. If you want the API on 5000, disable AirPlay Receiver in System Settings → General → AirDrop & Handoff, set `PORT=5000` in `backend-server/.env`, and set `REACT_APP_API_URL=http://localhost:5000` in `main-folder/.env.development`.

- Use Yarn if possible.
```
yarn start
yarn build
yarn test
yarn eject
```

- When commiting please write good commit message so everyone can understand. Also add your name before commit message
 - ~~this is commit~~ **Do _not_ do that**
 - name: updated readme file **Do this!**

- Some spacing tips while coding
```
~~if()~~ => if () 😄
~~y=10~~ => y = 10 😀
```

- Also please DO NOT use this bracket syntax while creating a function
```
function demo()
{

}
```

- Use this syntax while creating a function
```
function demo() {

}
```
## Enjoy coding. Don't stress we will be okay.