#!/usr/bin/env node

const path = require("path");
const fs = require("fs");
const V86 = require("@woodenfish/libv86").V86Starter;
const cli = require("cac").default();
const filer = require("filer");

function getFs9p() {
  return new Promise((resolve) => {
    const fs = new filer.FileSystem({ provider: new filer.FileSystem.providers.Memory() }, function ready() {
      const sh = new fs.Shell();

      resolve({
        fs,
        sh,
        Path: filer.Path,
        Buffer: filer.Buffer,
      });
    });
  });
}

cli.option("--image <image path>", "Specify a image directory");
cli.option("--shell <bash>", "Specify default shell");
cli.option("--out <file name>", "Specify output file name");
cli.option("--memory <memory size>", "Specify memory size");

const parsed = cli.parse();

const V86_ROOT = path.join(__dirname, "../node_modules/@woodenfish/libv86");
const IMAGE_ROOT = path.join(__dirname, "../images", parsed.options.image);
const IMAGE_FILE = path.join(IMAGE_ROOT, "linux.img");
const OUTPUT_FILE = path.join(IMAGE_ROOT, parsed.options.out || "state.bin");

function run(fs9p) {
  if (process.stdin.isTTY) {
    process.stdin.setRawMode(true);
  }
  process.stdin.resume();
  process.stdin.setEncoding("utf8");
  process.stdin.on("data", handle_key);

  const emulator = new V86({
    bios: { url: path.join(V86_ROOT, "/bios/seabios.bin") },
    vga_bios: { url: path.join(V86_ROOT, "/bios/vgabios.bin") },
    autostart: true,
    memory_size: parseInt(parsed.options.memory || "128") * 1024 * 1024,
    vga_memory_size: 8 * 1024 * 1024,
    network_relay_url: "<UNUSED>",
    hda: {
      url: IMAGE_FILE,
    },
    filesystem: fs9p,
    screen_dummy: true,
  });

  console.log("Now booting, please stand by ...");

  let boot_start = Date.now();
  let serial_text = "";
  let booted = false;

  emulator.add_listener("serial0-output-char", function (c) {
    process.stdout.write(c);

    serial_text += c;

    if (!booted && serial_text.endsWith("root@localhost:~# ")) {
      console.error("\nBooted in %d", (Date.now() - boot_start) / 1000);
      booted = true;

      if (parsed.options.shell) {
        emulator.serial0_send(`chsh -s /bin/${parsed.options.shell} && ${parsed.options.shell}\n`);
      }
      // sync and drop caches: Makes it safer to change the filesystem as fewer files are rendered
      emulator.serial0_send("sync;echo 3 >/proc/sys/vm/drop_caches\n");

      setTimeout(async function () {
        const s = await emulator.save_state();

        fs.writeFile(OUTPUT_FILE, new Uint8Array(s), function (e) {
          if (e) throw e;
          console.error("Saved as " + OUTPUT_FILE);
          stop();
        });
      }, 10 * 1000);
    }
  });

  function handle_key(c) {
    if (c === "\u0003") {
      // ctrl c
      stop();
    } else {
      emulator.serial0_send(c);
    }
  }

  function stop() {
    emulator.stop();
    process.stdin.pause();
  }
}

getFs9p().then(run);
