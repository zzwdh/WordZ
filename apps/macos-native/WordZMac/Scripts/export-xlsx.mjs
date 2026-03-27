import fs from "node:fs/promises";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const ExcelJS = require("exceljs");

const [, , payloadPath, outputPath] = process.argv;

if (!payloadPath || !outputPath) {
  console.error("Usage: node export-xlsx.mjs <payload.json> <output.xlsx>");
  process.exit(1);
}

const payload = JSON.parse(await fs.readFile(payloadPath, "utf8"));
const workbook = new ExcelJS.Workbook();
const worksheet = workbook.addWorksheet(payload.sheetName || "Results");

const headers = Array.isArray(payload.headers) ? payload.headers : [];
const rows = Array.isArray(payload.rows) ? payload.rows : [];

worksheet.addRow(headers);
for (const row of rows) {
  worksheet.addRow(Array.isArray(row) ? row : []);
}

if (headers.length > 0) {
  const headerRow = worksheet.getRow(1);
  headerRow.font = { bold: true };
  headerRow.alignment = { vertical: "middle" };
  worksheet.autoFilter = {
    from: { row: 1, column: 1 },
    to: { row: 1, column: headers.length }
  };
  worksheet.views = [{ state: "frozen", ySplit: 1 }];
}

for (let index = 1; index <= headers.length; index += 1) {
  const column = worksheet.getColumn(index);
  let maxLength = String(headers[index - 1] ?? "").length;
  for (const cell of column.values.slice(2)) {
    maxLength = Math.max(maxLength, String(cell ?? "").length);
  }
  column.width = Math.min(Math.max(maxLength + 2, 10), 48);
}

await workbook.xlsx.writeFile(outputPath);
