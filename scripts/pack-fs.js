const fs = require("fs/promises");
const path = require("path");
const V86 = require("@woodenfish/libv86").V86Starter;
const cli = require("cac").default();

cli.option("--image <image path>", "Specify a image directory");
const parsed = cli.parse();

const IMAGE_ROOT = path.join(__dirname, "../images", parsed.options.image);
const FS_BASE = path.join(IMAGE_ROOT, "rootfs-flat");
const PACK_DIST = path.join(IMAGE_ROOT, "pack-v2");

async function main() {
  await fs.mkdir(PACK_DIST);
  const result = await fs.readdir(FS_BASE);
  const map = {};

  for (const name of result) {
    const prefix = name.substring(0, 2);
    if (!map[prefix]) map[prefix] = [];

    const fileFullName = path.join(FS_BASE, name);
    const file = await fs.stat(fileFullName);
    const hash = name.split(".")[0];

    map[prefix].push(hash);
    map[prefix].push(file.size);

    const buff = await fs.readFile(fileFullName);
    await fs.appendFile(path.join(PACK_DIST, `${prefix}.pack`), buff);
  }

  for (const prefix of Object.keys(map)) {
    await fs.writeFile(path.join(PACK_DIST, `${prefix}.map.json`), JSON.stringify(map[prefix]));
  }

  console.log("pack done");
}

main();
