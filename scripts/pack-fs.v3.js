const fs = require("fs/promises");
const path = require("path");
const cbor = require("./cbor");
const cli = require("cac").default();

cli.option("--image <image path>", "Specify a image directory");
const parsed = cli.parse();

const IMAGE_ROOT = path.join(__dirname, "../images", parsed.options.image);
const FS_BASE = path.join(IMAGE_ROOT, "rootfs-flat");
const PACK_DIST = path.join(IMAGE_ROOT, "pack-v3");

// 16 MiB
const MAX_PACK_SIZE = 16 * 1024 * 1024;

async function pack() {
  await fs.mkdir(PACK_DIST);
  const fileList = await fs.readdir(FS_BASE);
  const result = [
    {
      size: 0,
      list: [],
    },
  ];

  for (const fileName of fileList) {
    const fileFullName = path.join(FS_BASE, fileName);

    const fileInfo = await fs.stat(fileFullName);
    // if (fileInfo.size > MAX_PACK_SIZE) {
    //   throw new Error(fileName + " size is too large " + fileInfo.size);
    // }

    let packIndex = result.findIndex((it) => it.size + fileInfo.size < MAX_PACK_SIZE);

    if (packIndex === -1) {
      result.push({
        size: 0,
        list: [],
      });

      packIndex = result.length - 1;
    }

    const pack = result[packIndex];
    pack.size += fileInfo.size;
    const fileNameHex = fileName.split(".")[0];
    pack.list.push(parseInt(fileNameHex, 16));
    pack.list.push(fileInfo.size);

    fs.appendFile(path.join(PACK_DIST, `${packIndex.toString(16)}.pack`), await fs.readFile(fileFullName));
  }

  // await fs.writeFile(path.join(PACK_DIST, "map.json"), JSON.stringify(result));
  await fs.writeFile(path.join(PACK_DIST, "map.cbor"), new Uint8Array(cbor.encode(result.map((it) => it.list))));
  await fs.writeFile(path.join(PACK_DIST, "map.json"), JSON.stringify(result.map((it) => it.list)));
  console.log("pack done");
}

pack();
