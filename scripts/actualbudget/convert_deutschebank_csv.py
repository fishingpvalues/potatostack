#!/usr/bin/env python3
"""Convert Deutsche Bank CSV exports to Actual Budget importable CSV."""

import csv
import sys
import os
import re


def parse_german_amount(text: str) -> str:
    """Convert German number format '1.234,56' to '1234.56'."""
    if not text or not text.strip():
        return ""
    text = text.strip()
    # Remove thousand separators (dots), swap decimal comma to dot
    text = text.replace(".", "").replace(",", ".")
    return text


def parse_german_date(text: str) -> str:
    """Convert 'D.M.YYYY' to 'YYYY-MM-DD'."""
    if not text or not text.strip():
        return ""
    parts = text.strip().split(".")
    if len(parts) != 3:
        return text
    day, month, year = parts
    return f"{year}-{int(month):02d}-{int(day):02d}"


def find_header_row(lines: list[str]) -> int:
    """Find the row index that starts with 'Buchungstag'."""
    for i, line in enumerate(lines):
        if line.startswith("Buchungstag"):
            return i
    raise ValueError("Could not find header row starting with 'Buchungstag'")


def convert(input_path: str, output_path: str | None = None) -> str:
    if output_path is None:
        base, _ = os.path.splitext(input_path)
        output_path = base + "_actualbudget.csv"

    # Deutsche Bank exports are UTF-8 with BOM
    with open(input_path, "r", encoding="utf-8-sig") as f:
        raw_lines = f.read().splitlines()

    header_idx = find_header_row(raw_lines)
    data_lines = raw_lines[header_idx:]

    reader = csv.reader(data_lines, delimiter=";")
    headers = next(reader)

    # Column indices we care about
    COL_DATE = headers.index("Buchungstag")
    COL_TYPE = headers.index("Umsatzart")
    COL_PAYEE = headers.index("Begünstigter / Auftraggeber")
    COL_NOTES = headers.index("Verwendungszweck")
    COL_AMOUNT = headers.index("Betrag")

    rows = []
    for row in reader:
        if not row or len(row) < len(headers):
            continue
        # Skip footer lines (e.g. "Kontostand;...")
        date_str = row[COL_DATE].strip()
        if not re.match(r"\d{1,2}\.\d{1,2}\.\d{4}", date_str):
            continue

        date = parse_german_date(date_str)
        payee = row[COL_PAYEE].strip()
        tx_type = row[COL_TYPE].strip()
        notes = row[COL_NOTES].strip()
        amount = parse_german_amount(row[COL_AMOUNT])

        if not amount:
            continue

        # Combine transaction type into notes for context
        if notes and tx_type:
            notes = f"{tx_type}: {notes}"
        elif tx_type and not notes:
            notes = tx_type

        rows.append({
            "Date": date,
            "Payee": payee,
            "Notes": notes,
            "Amount": amount,
        })

    with open(output_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["Date", "Payee", "Notes", "Amount"])
        writer.writeheader()
        writer.writerows(rows)

    print(f"Converted {len(rows)} transactions: {output_path}")
    return output_path


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: python {sys.argv[0]} <input.csv> [output.csv]")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else None
    convert(input_file, output_file)
