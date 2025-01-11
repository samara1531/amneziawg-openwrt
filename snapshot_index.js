const axios = require('axios');
const cheerio = require('cheerio');
const core = require('@actions/core');

const version = process.argv[2]; // Получение версии OpenWRT из аргумента командной строки

const SNAPSHOT_TARGETS_TO_BUILD = ['mediatek', 'ramips', 'x86', 'armsr', 'rockchip'];
const SNAPSHOT_SUBTARGETS_TO_BUILD = ['filogic', 'mt7622', 'mt7623', 'mt7629', 'mt7620', 'mt7621', 'mt76x8', '64', 'generic', 'armv8'];

if (!version || version !== 'SNAPSHOT') {
  core.setFailed('Only "SNAPSHOT" version is supported');
  process.exit(1);
}

const url = 'https://downloads.openwrt.org/snapshots/targets/';

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
  const kmodsUrl = `${url}${target}/${subtarget}/kmods/`;
  let vermagic = '';
  let pkgarch = '';

  try {
    // Получаем HTML страницы с kmods
    const $ = await fetchHTML(kmodsUrl);
    const kmodsLinks = [];

    // Собираем все ссылки, соответствующие шаблону 6.6.54-1-45f373ce241c6113ae3c7cbbdc506b11
    $('a').each((index, element) => {
      const name = $(element).attr('href');
      console.log('Found kmod link:', name);  // Логируем все ссылки
      if (name && name.match(/^\d+\.\d+\.\d+-\d+-[a-f0-9]{32}\/$/)) {
        kmodsLinks.push(name);
      }
    });

    console.log('Kmods links found:', kmodsLinks); // Логируем массив ссылок

    if (kmodsLinks.length >= 7) {
      // Берем седьмую ссылку из найденных
      const seventhKmodLink = kmodsLinks[1]; // Индексация с 0, поэтому седьмой элемент — это kmodsLinks[6]
      const seventhKmodUrl = `${kmodsUrl}${seventhKmodLink}index.json`; // Переход по седьмой ссылке и получаем index.json

      console.log(`Fetching index.json from: ${seventhKmodUrl}`); // Логируем URL для index.json

      // Загружаем index.json для получения pkgarch
      const response = await axios.get(seventhKmodUrl);
      const data = response.data;
      if (data && data.architecture) {
        pkgarch = data.architecture;
        console.log(`Found pkgarch: ${pkgarch} for ${target}/${subtarget}`);
      }
    } else {
      console.log('Not enough kmod links found to select the seventh one.');
    }

    // Получаем информацию о vermagic из пакетов ядра на странице packages/
    const packagesUrl = `${url}${target}/${subtarget}/packages/`;
    const $packages = await fetchHTML(packagesUrl);
    $('a').each((index, element) => {
      const name = $(element).attr('href');
      if (name && name.startsWith('kernel-')) {
        // Обновленное регулярное выражение для извлечения vermagic
        const vermagicMatch = name.match(/kernel-\d+\.\d+\.\d+~([a-f0-9]{32})(?:-r\d+)?\.apk$/);
        if (vermagicMatch) {
          vermagic = vermagicMatch[1];  // Сохраняем значение vermagic
          console.log(`Found vermagic: ${vermagic} for ${target}/${subtarget}`);
        }
      }
    });

  } catch (error) {
    console.error(`Error fetching data for ${target}/${subtarget}: ${error.message}`);
  }

  return { vermagic, pkgarch };
}

async function main() {
  try {
    const targets = await getTargets();
    const jobConfig = [];

    for (const target of targets) {
      const subtargets = await getSubtargets(target);
      for (const subtarget of subtargets) {
        const { vermagic, pkgarch } = await getDetails(target, subtarget);

        if (SNAPSHOT_SUBTARGETS_TO_BUILD.includes(subtarget) && SNAPSHOT_TARGETS_TO_BUILD.includes(target)) {
          jobConfig.push({
            tag: version,
            target,
            subtarget,
            vermagic,
            pkgarch,
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
