(() => {
  "use strict";
  const API = "https://api.github.com/repos/Swrang120/SMART-MONEY-SOCIAL/releases/latest";
  const native = window.Capacitor;
  if (!native || typeof native.getPlatform !== "function" || native.getPlatform() !== "android") return;
  const plugin = native.Plugins && native.Plugins.SmartAppUpdater;
  if (!plugin) { console.warn("[SM Update] Native updater plugin is not registered."); return; }
  let panel, statusNode, progressNode, actionButton, latestAssetUrl = "", checking = false;
  function ensurePanel() {
    if (panel) return;
    panel = document.createElement("div");
    panel.id = "sm-app-update-panel";
    panel.innerHTML = '<div class="sm-update-card" role="dialog" aria-modal="true" aria-labelledby="sm-update-title"><div class="sm-update-icon">↻</div><div class="sm-update-kicker">SMART MONEY SOCIAL</div><h2 id="sm-update-title">New update available</h2><p class="sm-update-version"></p><p class="sm-update-notes"></p><div class="sm-update-progress"><span></span></div><p class="sm-update-status" aria-live="polite">A newer version is ready.</p><div class="sm-update-actions"><button type="button" class="sm-update-later">Later</button><button type="button" class="sm-update-now">Update now</button></div><p class="sm-update-help">Android will ask you to confirm installation. Updates are never installed silently.</p></div>';
    const style = document.createElement("style");
    style.textContent = '#sm-app-update-panel{position:fixed;inset:0;z-index:99999;display:none;place-items:center;padding:18px;background:rgba(10,15,28,.68);backdrop-filter:blur(8px)}#sm-app-update-panel.open{display:grid}.sm-update-card{width:min(420px,100%);padding:25px;border:1px solid #e4def3;border-radius:24px;background:linear-gradient(145deg,#fff,#f5f2ff);box-shadow:0 24px 80px #0005;color:#242235;text-align:center;font-family:system-ui,sans-serif}.sm-update-icon{width:58px;height:58px;margin:0 auto 12px;border-radius:18px;display:grid;place-items:center;background:linear-gradient(135deg,#a78bfa,#7046d2);color:white;font-size:32px;font-weight:800}.sm-update-kicker{font-size:10px;letter-spacing:2px;font-weight:850;color:#7657bb}.sm-update-card h2{margin:7px 0;font-size:22px}.sm-update-card p{font-size:13px;line-height:1.55;color:#696579}.sm-update-version{font-weight:800;color:#51418c!important}.sm-update-progress{height:7px;border-radius:99px;background:#e8e3f1;overflow:hidden;margin:15px 0 7px;display:none}.sm-update-progress span{display:block;width:0;height:100%;background:linear-gradient(90deg,#8b5cf6,#477be8);transition:width .2s}.sm-update-actions{display:flex;gap:10px;margin-top:17px}.sm-update-actions button{flex:1;border:0;border-radius:12px;padding:12px;font-weight:800}.sm-update-later{background:#eceaf2;color:#4c4859}.sm-update-now{background:linear-gradient(135deg,#9874ed,#6742c5);color:#fff}.sm-update-help{font-size:10px!important;margin-bottom:0}';
    document.head.appendChild(style); document.body.appendChild(panel);
    statusNode=panel.querySelector(".sm-update-status"); progressNode=panel.querySelector(".sm-update-progress"); actionButton=panel.querySelector(".sm-update-now");
    panel.querySelector(".sm-update-later").addEventListener("click",()=>panel.classList.remove("open"));
    actionButton.addEventListener("click",install);
    if(typeof plugin.addListener==="function") plugin.addListener("downloadProgress",event=>{progressNode.style.display="block";progressNode.firstElementChild.style.width=Math.max(0,Math.min(100,Number(event.percent)||0))+"%";statusNode.textContent="Downloading update… "+Math.round(Number(event.percent)||0)+"%";});
  }
  async function checkUpdate() {
    if(checking||document.visibilityState==="hidden") return; checking=true;
    try {
      const [installed,response]=await Promise.all([plugin.getAppVersion(),fetch(API,{cache:"no-store",headers:{Accept:"application/vnd.github+json"}})]);
      if(!response.ok) throw new Error("Release check unavailable ("+response.status+")");
      const release=await response.json(), match=/^sm-social-(\d+)$/.exec(String(release.tag_name||""));
      if(!match) return;
      const latestCode=Number(match[1]),currentCode=Number(installed.versionCode||0);
      if(!Number.isFinite(latestCode)||latestCode<=currentCode) return;
      const asset=(release.assets||[]).find(item=>item.name==="smart-money-social.apk");
      if(!asset||!asset.browser_download_url) throw new Error("Update APK asset is missing.");
      latestAssetUrl=asset.browser_download_url; ensurePanel();
      panel.querySelector(".sm-update-version").textContent="Version "+(release.name||"New version")+" · Installed "+(installed.versionName||currentCode);
      panel.querySelector(".sm-update-notes").textContent=String(release.body||"Performance improvements and fixes.").replace(/[\r\n]+/g," ").slice(0,260);
      statusNode.textContent="A newer version is ready to install.";progressNode.style.display="none";actionButton.disabled=false;actionButton.textContent="Update now";panel.classList.add("open");
    } catch(error) { console.info("[SM Update]",error&&error.message?error.message:error); }
    finally { checking=false; }
  }
  async function install() {
    if(!latestAssetUrl) return; actionButton.disabled=true;actionButton.textContent="Preparing…";statusNode.textContent="Checking Android install permission…";
    try {
      const result=await plugin.installApk({url:latestAssetUrl});
      if(result&&result.permissionRequired){statusNode.textContent="Allow “Install unknown apps” for Smart Money Social in Android Settings, then return here and tap Retry.";actionButton.disabled=false;actionButton.textContent="Retry installation";return;}
      statusNode.textContent="Download complete. Confirm the Android installation prompt.";actionButton.textContent="Installer opened";
    } catch(error) {statusNode.textContent=error&&error.message?error.message:"Could not start the update. Please try again.";actionButton.disabled=false;actionButton.textContent="Try again";}
  }
  function start(){setTimeout(checkUpdate,1800);document.addEventListener("visibilitychange",()=>{if(document.visibilityState==="visible")checkUpdate();});window.addEventListener("pageshow",checkUpdate);window.setInterval(checkUpdate,6*60*60*1000);}
  if(document.readyState==="loading")document.addEventListener("DOMContentLoaded",start,{once:true});else start();
})();