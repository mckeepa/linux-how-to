const fs = require('fs');
const readline = require('readline');
const { spawnSync } = require('child_process');

const RED = '\x1b[31m';
const GREEN = '\x1b[32m';
const NC = '\x1b[0m';

if (process.argv.length < 3 || process.argv.length > 4) {
  console.log('Usage: node testsites_csv.js <user_sites.csv> [unexpected_only]');
  process.exit(1);
}

const CSV = process.argv[2];
const UNEXPECTED_ONLY = process.argv[3] === 'unexpected_only';

async function processCSV() {
  const rl = readline.createInterface({
    input: fs.createReadStream(CSV),
    crlfDelay: Infinity
  });

  let isHeader = true;
  for await (const line of rl) {
    if (isHeader) {
      isHeader = false;
      continue;
    }
    if (!line.trim() || line.trim().startsWith('#')) continue;

    // Split CSV, handle possible commas in URLs
    const [user, access, ...siteParts] = line.split(',');
    const site = siteParts.join(',').trim();

    if (!user || !access || !site) continue;

    // Use curl to check site accessibility
    const curl = spawnSync('curl', ['-s', '--head', '--fail', site]);
    const accessible = curl.status === 0;

    if (access.trim() === 'allow') {
      if (accessible) {
        if (!UNEXPECTED_ONLY) {
          console.log(`[${user.trim()}]\tALLOWED\t${GREEN}\t${curl.status}\t${site}\tis accessible \texpected${NC}`);
        }
      } else {
        console.log(`[${user.trim()}]\tALLOWED\t${RED}\t${curl.status}\t${site}\tis NOT accessible \tunexpected!${NC}`);
      }
    } else if (access.trim() === 'deny') {
      if (accessible) {
        console.log(`[${user.trim()}]\tDENIED\t${RED}\t${curl.status}\t${site}\tis accessible \tunexpected!${NC}`);
      } else {
        if (!UNEXPECTED_ONLY) {
          console.log(`[${user.trim()}]\tDENIED\t${GREEN}\t${curl.status}\t${site}\tis NOT accessible \texpected${NC}`);
        }
      }
    }
  }
}

processCSV();