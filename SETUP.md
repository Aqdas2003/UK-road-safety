# Setup guide

You already have PostgreSQL, Python and Git installed from the house prices project, so this is quicker. Each step shows the result you should see.

---

### Step 1: Unzip the project
Put the zip in your projects folder, then in PowerShell:
```
cd D:\data_analyst_project
Expand-Archive uk-road-safety.zip -DestinationPath .
cd uk-road-safety
dir
```
**Result:** a list including `README.md`, `run_all.sql`, `SETUP.md` and the folders `powerbi`, `scripts` and `sql`.

---

### Step 2: Install the Python packages
```
pip install -r requirements.txt
```
**Result:** `Successfully installed ...`, or `Requirement already satisfied` for packages you already have.

---

### Step 3: Download and prepare the data
```
python scripts/prepare_data.py
```
**Result** (takes 1–3 minutes):
```
[get ] collision.csv ...
[done] collision.csv (98 MB)
[get ] vehicle.csv ...
[done] vehicle.csv (104 MB)
[get ] casualty.csv ...
[done] casualty.csv (54 MB)
[get ] guide.xlsx ...
[done] guide.xlsx (0 MB)
[info] lookups: 1769 codes (5 duplicates removed)
[done] lookups.csv
[ok  ] collision.csv: 44 columns, all required columns present
[ok  ] vehicle.csv: 32 columns, all required columns present
[ok  ] casualty.csv: 24 columns, all required columns present
```
If you see `[FAIL] ... missing columns`, DfT has changed its file format. Paste the message to get help.

---

### Step 4: Create the database
```
$env:PGPASSWORD = "yourpassword"
createdb -U postgres road_safety
```
**Result:** nothing is printed, which means it worked.

---

### Step 5: Run the pipeline
```
psql -U postgres -d road_safety -f run_all.sql
```
**Result** (about 2–5 minutes). There are no `-- More --` pauses this time, because the pager is switched off inside `run_all.sql`. Here's what to look for:

```
== 2/10 Loading CSVs ==
COPY 513801
COPY 937265
COPY 652821
COPY 1769
```
```
== 4/10 Data quality checks ==
 orphan_casualties | orphan_vehicles
-------------------+-----------------
                 0 |               0
```
```
== 5/10 Trends ==
  yr  | casualties | killed | ksi_adjusted | ...
 2025 |     127883 |   1538 |        29918 | ...
```
```
== 9/10 Power BI views + export ==
Exported powerbi/data/*.csv and results/*.csv
== 10/10 Road Safety Strategy target tracking ==
== Done ==
```

**If PowerShell looks frozen:** a query is still running. Wait for it to finish; it won't need a keypress.

---

### Step 6: Make the charts
```
python scripts/make_charts.py
```
**Result:** `Charts saved to ...\results\charts`, and three PNG images in that folder.

---

### Step 7: Build the dashboard
Follow `powerbi/BUILD_GUIDE.md`. It's the longest step (about 2–3 hours), and it works the same way as this guide, with the result shown after every step.

---

### Step 8: Upload to GitHub
First create an empty public repo called `uk-road-safety` on github.com. Then run:
```
git init
git add .
git status
```
**Result:** a list of green files. **`data/` and `powerbi/data/` must not appear in it.**

Then run:
```
git commit -m "GB road safety analysis: PostgreSQL + Power BI"
git branch -M main
git remote add origin https://github.com/Aqdas2003/uk-road-safety.git
git push -u origin main
```
**Result:** `* [new branch] main -> main`. Refresh GitHub, and the README appears with the charts.

You can upload the SQL part first, then do a second push once the dashboard is finished (Step 14 of the build guide).

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `could not open file "data/collision.csv"` | You're in the wrong folder. `cd` into the folder that contains `run_all.sql`. |
| `could not open file "powerbi/data/..." for writing` | Run `python scripts/prepare_data.py` again. It creates that folder. |
| `database "road_safety" already exists` | That's fine, skip `createdb`. |
| `password authentication failed` | Run the `$env:PGPASSWORD = ...` line again. It resets whenever PowerShell closes. |
| `No module named 'openpyxl'` | Run Step 2 again. |
