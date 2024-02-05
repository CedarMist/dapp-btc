import { defineConfig } from 'vite'
import { viteSingleFile } from "vite-plugin-singlefile"

import minifyHTML from 'rollup-plugin-minify-html-literals';

import { readFile } from 'node:fs/promises';
import { execSync } from 'node:child_process';

import { visualizer } from 'rollup-plugin-visualizer';


const package_json = JSON.parse(await readFile('package.json', {encoding: 'utf-8'}));

const commitDate = execSync('git log -1 --format=%as').toString().trimEnd();
const commitHash = execSync('git rev-parse HEAD').toString().trimEnd();

process.env.VITE_PACKAGE_VERSION = package_json['version'];
process.env.VITE_PACKAGE_NAME = package_json['name'];
process.env.VITE_GIT_COMMIT_DATE = commitDate;
process.env.VITE_GIT_COMMIT_HASH = commitHash;
process.env.VITE_GIT_COMMIT_SHORT_HASH = commitHash.slice(0, 16);

export default defineConfig({
    build: {
        sourcemap: false
    },
    plugins: [
        viteSingleFile({
            removeViteModuleLoader: true,
        }),
        minifyHTML.default(),
        visualizer({
            sourcemap: false,
            gzipSize: true
        }),
    ],
});
