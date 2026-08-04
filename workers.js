const REPO = "CydiaBlock/AppStore";
const RELEASES = new Set(["game", "application"]);
const INDEXES = new Set(["Packages", "Packages.gz"]);

const rawFile = (name) =>
  `https://raw.githubusercontent.com/${REPO}/main/${name}`;

export default {
  async fetch(request) {
    if (request.method !== "GET" && request.method !== "HEAD") {
      return new Response("Method not allowed", {
        status: 405,
        headers: { Allow: "GET, HEAD" },
      });
    }

    const path = new URL(request.url).pathname.split("/").filter(Boolean);
    if (path.length === 1 && INDEXES.has(path[0])) {
      return fetch(new Request(rawFile(path[0]), request), { redirect: "follow" });
    }

    if (path.length < 2 || !RELEASES.has(path[0])) {
      return new Response("Not found", { status: 404 });
    }

    const tag = path[0];
    let asset;
    try {
      asset = path.slice(1).map(decodeURIComponent).join("/");
    } catch {
      return new Response("Not found", { status: 404 });
    }
    if (!asset.endsWith(".deb") || asset.includes("..")) {
      return new Response("Not found", { status: 404 });
    }

    const origin = `https://github.com/${REPO}/releases/download/${tag}/${encodeURIComponent(asset)}`;
    return fetch(new Request(origin, request), { redirect: "follow" });
  },
};
