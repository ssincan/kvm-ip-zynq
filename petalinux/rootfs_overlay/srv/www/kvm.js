// Based on https://github.com/mdn/dom-examples/tree/master/pointer-lock, licensed under the Creative Commons Zero v1.0 Universal License

// setup of the canvas

var canvas = document.getElementById("video_space");

// pointer lock object forking for cross browser

canvas.requestPointerLock = canvas.requestPointerLock ||
                            canvas.mozRequestPointerLock;

document.exitPointerLock = document.exitPointerLock ||
                           document.mozExitPointerLock;

canvas.onclick = function() {
  canvas.requestPointerLock();
};

var x_accum = 0;
var y_accum = 0;
var l_click = 0;
var r_click = 0;
var pending_mouse = 0;

// pointer lock event listeners

// Hook pointer lock state change events for different browsers
document.addEventListener('pointerlockchange', lockChangeAlert, false);
document.addEventListener('mozpointerlockchange', lockChangeAlert, false);

function lockChangeAlert() {
  if (document.pointerLockElement === canvas ||
      document.mozPointerLockElement === canvas) {
    document.addEventListener("mousemove", updatePosition, false);
    document.addEventListener("click", doClick, false);
    document.addEventListener("keydown", keyDown, false);
    document.addEventListener("keyup", keyUp, false);
  } else {
    document.removeEventListener("mousemove", updatePosition, false);
    document.removeEventListener("click", doClick, false);
    document.removeEventListener("keydown", keyDown, false);
    document.removeEventListener("keyup", keyUp, false);
  }
}

var HttpClient = function() {
  this.get = function(aUrl, aCallback) {
    var anHttpRequest = new XMLHttpRequest();
    anHttpRequest.onreadystatechange = function() { 
      if (anHttpRequest.readyState == XMLHttpRequest.DONE && anHttpRequest.status == 200)
        aCallback(anHttpRequest.responseText);
    };
    anHttpRequest.open("GET", aUrl, true);            
    anHttpRequest.send();
  };
};

function serverUpdate() {
  if (pending_mouse == 0) {
    if ((x_accum != 0) || (y_accum != 0) || (l_click != 0) || (r_click != 0)) {
      var client = new HttpClient();
      pending_mouse = 1;
      //console.log("Request cgi-bin/mouse?dx="+x_accum+"&dy="+y_accum+"&lc="+l_click+" ...");
      client.get("cgi-bin/mouse?dx="+x_accum+"&dy="+y_accum+"&lc="+l_click+"&rc="+r_click, function(response) {
        pending_mouse = 0;
        //console.log('Response: '+response);
      });
      x_accum = 0;
      y_accum = 0;
      l_click = 0;
      r_click = 0;
    }
  }
}

function updatePosition(e) {
  x_accum+=e.movementX;
  y_accum+=e.movementY;
  //console.log('MouseMove: dx = ' + e.movementX + ', dy = ' + e.movementY + '.');  
}

function doClick(e) {
  if (e.which) {
    btn = e.which;
  }
  if (e.button) {
    btn = e.button;
  }
  if (btn==1) {
    l_click = 1;
  } else {
    r_click = 1;
  }
  //console.log('Click. Button ' + btn);  
}

function keyDown(e) {
  e.preventDefault();
  //console.log('KeyDown: ' + e.which + ' (' + keyCodes[e.which]+ ').');
}

function keyUp(e) {
  e.preventDefault();
  //console.log('KeyUp: ' + e.which + ' (' + keyCodes[e.which]+ ').');
}

var mouseupdate = setInterval("serverUpdate()",1);


var img_ch0 = new Image();
var img_ch1 = new Image();
var img_ch2 = new Image();
var img_ch3 = new Image();
var img_cnt = 0;
var go = 1;
var lastGo = 0;
img_ch0.onload = function(){
    img_cnt--;
    if (img_cnt==0) {
        document.getElementById('ch0').src = img_ch0.src;
        document.getElementById('ch1').src = img_ch1.src;
        document.getElementById('ch2').src = img_ch2.src;
        document.getElementById('ch3').src = img_ch3.src;
        go = 1;
    }
};
img_ch1.onload = img_ch0.onload;
img_ch2.onload = img_ch0.onload;
img_ch3.onload = img_ch0.onload;
function ChangeMedia(){
    var d = new Date();
    var t = d.getTime();
    if (go==1) {
        lastGo = t;
        go = 0;
        img_cnt += 4;
        img_ch0.src = "cgi-bin/getimg0?t="+t+"&ext=.jpeg";
        img_ch1.src = "cgi-bin/getimg1?t="+t+"&ext=.jpeg";
        img_ch2.src = "cgi-bin/getimg2?t="+t+"&ext=.jpeg";
        img_ch3.src = "cgi-bin/getimg3?t="+t+"&ext=.jpeg";
    } else if ((t-lastGo)>=1000) {
        location.reload();
    }
}
var reloadcam = setInterval("ChangeMedia()",1);

