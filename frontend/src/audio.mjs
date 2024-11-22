export function audio() {
  return new Audio()
}


export function documentAudio(id) {
  return document.getElementById(id)
}

export function setSRC(audio) {
  audio.src = src;
  return audio
}

export function resetAudio(audio) {
  audio.pause();
  audio.currentTime = 0;
  audio.src = "";
  audio.removeAttribute("src")
  return audio
}

export function debugAudio(audio) {
  console.log(audio)
  return audio
}

export function setVolume(audio,volume) {
  if (volume > 0) {
    audio.volume = volume;
  }
}
