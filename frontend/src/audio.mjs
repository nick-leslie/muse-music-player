export function audio() {
  return new Audio()
}


export function documentAudio(id) {
  return document.getElementById(id)
}

export function setSrc(audio,src) {
  audio.setAttribute("src",src)
  return audio
}
/**
 * Represents a book.
 * @param {HTMLAudioElement} audio - The author of the book.
 */
export function resetAudio(audio) {
  audio.pause()
  audio.currentTime = 0;
  audio.src = "";
  audio.removeAttribute("src")
  return audio
}

export function setPlaying(audio,playing) {
  if(playing === true) {
    audio.play();
    return audio;
  }
  audio.pause();
  return audio;
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


export function wsTest() {
  ws = new WebSocket("ws://localhost:3000/healthcheck")
  ws.onmessage = () => {
    console.log("if this works im gonna be so sad")
  }
  return "gaming"
}
