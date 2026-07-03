/** Friendly label for headers, greetings, profile (not login). */
export function displayName(user) {
  if (!user) return '';
  const first = user.firstName?.trim();
  if (first) return first;
  if (user.email) {
    const local = user.email.split('@')[0];
    return local || user.email;
  }
  return user.username || '';
}

export function avatarLetter(user) {
  const name = displayName(user);
  return name.charAt(0).toUpperCase() || '?';
}
