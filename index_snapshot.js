const axios = require('axios');
const cheerio = require('cheerio');
const core = require('@actions/core');

const version = process.argv[2]; // Получение версии OpenWRT из аргумента командной строки

const SNAPSHOT_TARGETS_TO_BUILD = ['rockchip'];
const SNAPSHOT_SUBTARGETS_TO_BUILD = ['armv8'];
const SNAPSHOT_PKGARCHS_TO_BUILD = ['aarch64_generic'];

if (!version) {
  core.setFailed('Version argument is required');
  process.exit(1);
}

const url = version === 'SNAPSHOT' ? 'https://downloads.openwrt.org/snapshots/targets/' : `https://downloads.openwrt.org/releases/${version}/targets/`;

async function fetchHTML(url) {
  try {
    const { data } = await axios.get(url);
    return cheerio.load(data);
  } catch (error) {
    console.error(`Error fetching HTML for ${url}: ${error}`);
    throw error;
  }
}

async function getTargets() {
  const $ = await fetchHTML(url);
  const targets = [];
  $('table tr td.n a').each((index, element) => {
    const name = $(element).attr('href');
    if (name && name.endsWith('/')) {
      targets.push(name.slice(0, -1));
    }
  });
  return targets;
}

async function getSubtargets(target) {
  const $ = await fetchHTML(`${url}${target}/`);
  const subtargets = [];
  $('table tr td.n a').each((index, element) => {
    const name = $(element).attr('href');
    if (name && name.endsWith('/')) {
      subtargets.push(name.slice(0, -1));
    }
  });
  return subtargets;
}

async function getDetails(target, subtarget) {
  const packagesUrl = `${url}${target}/${subtarget}/packages/`;
  const $ = await fetchHTML(packagesUrl);
  let vermagic = '';

  $('a').each((index, element) => {
    const name = $(element).attr('href');
    if (name && name.startsWith('kernel_')) {
      const vermagicMatch = name.match(/kernel_\d+\.\d+\.\d+(?:-\d+)?[-~]([a-f0-9]+)(?:-r\d+)\.apk$/);
      if (vermagicMatch) {
        vermagic = vermagicMatch[1];
      }
    }
  });

  return { vermagic };
}

async function main() {
  try {
    const targets = await getTargets();
    const jobConfig = [];

    for (const target of targets) {
      const subtargets = await getSubtargets(target);
      for (const subtarget of subtargets) {
        const { vermagic } = await getDetails(target, subtarget);

        if (version !== 'SNAPSHOT' || (SNAPSHOT_SUBTARGETS_TO_BUILD.includes(subtarget)  && SNAPSHOT_PKGARCHS_TO_BUILD.includes(pkgarch) && SNAPSHOT_TARGETS_TO_BUILD.includes(target))) {
          jobConfig.push({
            tag: version,
            target,
            subtarget,
            pkgarch,
            vermagic,
          });
        }
      }
    }

    core.setOutput('job-config', JSON.stringify(jobConfig));
  } catch (error) {
    core.setFailed(error.message);
  }
}

main();
