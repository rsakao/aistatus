const releaseEndpoint = "https://api.github.com/repos/rsakao/aistatus/releases/latest";
const releaseFallback = "https://github.com/rsakao/aistatus/releases/latest";

async function updateLatestRelease() {
  try {
    const response = await fetch(releaseEndpoint, {
      headers: { Accept: "application/vnd.github+json" }
    });
    if (!response.ok) return;

    const release = await response.json();
    const installer = release.assets?.find((asset) => asset.name?.endsWith("-universal.pkg"));
    const url = installer?.browser_download_url ?? release.html_url ?? releaseFallback;

    document.querySelectorAll(".download-link").forEach((link) => {
      link.href = url;
    });
    document.querySelectorAll(".release-label").forEach((label) => {
      label.textContent = release.tag_name ?? "Latest release";
    });
  } catch {
    // Keep the GitHub Releases fallback when the public API is unavailable.
  }
}

updateLatestRelease();
