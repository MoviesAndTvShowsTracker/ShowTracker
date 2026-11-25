/**
 * What a failed request returns. Client errors (4xx) keep their message; anything else gets a
 * generic one, so database or upstream details never reach the client (they are logged instead).
 */
function errorResponse(err) {
  const status = Number(err && err.status) || 500;
  if (status >= 400 && status < 500) {
    return { status, body: { success: false, message: err.message || 'Request failed.' } };
  }
  return { status, body: { success: false, message: 'Something went wrong. Try again.' } };
}

module.exports = { errorResponse };
