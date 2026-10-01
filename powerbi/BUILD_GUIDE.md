# Power BI build guide

This guide builds the dashboard step by step. Each step shows the result you should see, so you can check your work as you go. Allow about 2–3 hours the first time.

**Before you start:** run the SQL pipeline (see `SETUP.md`). You should have three files in `powerbi/data/`: `collisions.csv`, `casualties.csv` and `authorities.csv`.

Install **Power BI Desktop** (free) from the Microsoft Store. It's Windows only.

---

## Part A: Load and model the data

### Step 1: Import the three CSVs
Go to **Home → Get data → Text/CSV** and choose `powerbi/data/collisions.csv`. In the preview window, click **Transform Data**. Don't click Load yet.

**Result:** the Power Query editor opens with a `collisions` query.

Repeat this for `casualties.csv` and `authorities.csv`: go to **Home → New Source → Text/CSV** inside Power Query.

**Result:** three queries are listed on the left.

### Step 2: Check the data types
Power Query guesses column types, and sometimes gets them wrong. Click each column's type icon (next to its header) and set:

| Table | Column | Type |
|---|---|---|
| collisions | `collision_id`, `la_code` | Text |
| collisions | `collision_date` | Date |
| collisions | `ksi_adjusted`, `latitude`, `longitude` | Decimal number |
| casualties | `collision_id`, `casualty_key` | Text |
| casualties | `ksi_adjusted` | Decimal number |

Then click **Home → Close & Apply**.

**Result:** a loading bar appears, then three tables show in the **Data** pane on the right. Loading 1.1 million rows takes a minute or two.

### Step 3: Create the date table
Click **Modeling → New table**, then paste the `Date` block from `DAX_measures.dax`.

**Result:** a new `Date` table appears with 1,826 rows (every day from 2021 to 2025).

Now select `Date` in the Data pane, then choose **Table tools → Mark as date table** and pick the `Date` column.

### Step 4: Set up the relationships
Click the **Model view** icon on the left (the third icon). Drag between fields to create these three relationships:

| From (one side) | To (many side) |
|---|---|
| `authorities[la_code]` | `collisions[la_code]` |
| `Date[Date]` | `collisions[collision_date]` |
| `collisions[collision_id]` | `casualties[collision_id]` |

If Power BI has created any relationship automatically, check it matches this table and delete any extras.

**Result:** a chain of tables: authorities → collisions → casualties, with Date → collisions. Each line shows **1** at one end and **\*** at the other, and an arrow pointing *towards* the many side.

> **Why this shape?** A filter on authority or date flows into collisions, and from there into casualties. So one slicer filters every visual on the page.

### Step 5: Set the sort orders
Some text columns would otherwise sort alphabetically. In **Table view**, select each column below, then choose **Column tools → Sort by column**:

- `collisions[day_name]` → sort by `day_sort` (Monday first, not Friday)
- `casualties[age_band]` → sort by `age_band_sort` (0–5 first, not 11–15)
- `Date[Month]` → sort by `Month Number`

Then select `collisions[latitude]` and set **Column tools → Data category → Latitude**. Do the same for `longitude`, choosing **Longitude**.

**Result:** nothing visible changes yet. You'll see the effect in the charts.

### Step 6: Add the measures
Go to **Home → Enter data**, name the table `_Measures` and click **Load**. Then right-click `_Measures` → **New measure**, and paste each measure from `DAX_measures.dax` one at a time.

**Result:** after creating a few measures, delete the blank `Column1` in `_Measures`. The table's icon changes to a calculator, and it moves to the top of the Data pane.

**Quick check:** drop a **Card** visual onto the page, and drag `KSI (adjusted)` into it.

**Result:** it shows about **143K**. If it does, your data and model are correct. Delete the card.

### Step 7: Apply the theme
Go to **View → Themes → Browse for themes** and choose `powerbi/theme.json`.

**Result:** the colours change to blue and red.

---

## Part B: Build the pages

Build the pages **Overview**, **When**, **Where** and **Who**. To rename a page, double-click its tab at the bottom.

### Step 8: Overview page

1. **Slicers:** add three **Slicer** visuals, for `Date[Year]`, `authorities[nation]` and `authorities[la_name]`. For the authority slicer, turn on **Search** in the Format pane.
2. **KPI cards:** add four **Card** visuals for `Casualties`, `Killed`, `KSI (adjusted)` and `KSI vs Baseline %`.
3. **Target chart:** add a **Line chart** with X-axis `Date[Year]` and Y-axis `KSI (adjusted)`, `KSI Baseline 2022-24` and `KSI 2035 Target`.
4. **Map:** add an **Azure Map** visual with `latitude` and `longitude` from `collisions`. Drag `collisions[is_fatal]` into the **Filters on this visual** area and set it to **is 1**.

**Result:** select **2025** in the year slicer. The cards should read **127,883**, **1,538**, **29,918** and **+3.4%**. These match the official DfT statistics exactly. The map shows 1,453 dots, one for each fatal collision.

> **If the map is blank:** go to **File → Options and settings → Options → Security** and tick **Use Map and Filled Map visuals**, and the Azure Map setting if it's listed. Then restart Power BI.

### Step 9: When page

1. **Heatmap:** add a **Matrix** with Rows `day_name`, Columns `collision_hour` and Values `Collisions`. Then go to **Format → Cell elements → Background color → On**.
2. **Line chart:** set X-axis to `collision_hour` and Y-axis to `KSI % of Casualties`.

**Result:** the matrix shows a grid with the darkest cells on weekday afternoons (15:00–18:00). Weekend mornings are lighter, but the early hours (00:00–05:00) on Saturdays and Sundays are about twice as busy as on weekdays. In the line chart, severity is highest between midnight and 5am.

### Step 10: Where page

1. **Column chart:** set X-axis to `speed_limit` and Y-axis to `Fatal Collisions per 1,000`. In the Format pane, set the X-axis **Type** to **Categorical**.
2. **Bar chart:** set Y-axis to `light` and X-axis to `Fatal Collisions per 1,000`.
3. **Table:** add `la_name`, `Collisions`, `KSI (adjusted)` and `KSI % of Casualties`. Click the `KSI % of Casualties` header to sort, and add data bars with **Format → Cell elements → Data bars**.

**Result:** the speed chart rises from about **4.7** at 20 mph to about **38.4** at 60 mph. Unlit roads at night come out at about **48**, four times the daylight figure.

### Step 11: Who page

1. **Clustered bar chart:** set Y-axis to `road_user_group`, and X-axis to `Share of Casualties` and `Share of Deaths`.
2. **Column chart:** set X-axis to `age_band` and Y-axis to `Deaths per 1,000 Casualties`.
3. **Card:** add `Child KSI`.

**Result:** motorcyclists and pedestrians each make up around 12–15% of casualties but more than 20% of deaths. The age chart climbs steeply after 65, and the Over 75 band reaches about 43.

### Step 12: Test the interactivity
On the Overview page, type **Newcastle** in the authority slicer and select it.

**Result:** every visual on the page updates, and the map zooms in to Newcastle's fatal collisions. Clear the slicer when you're done.

---

## Part C: Save and publish to GitHub

### Step 13: Save the files
1. Go to **File → Save as** and save it as `powerbi/road_safety_dashboard.pbix`.
2. Go to **File → Export → Export to PDF**, and save the PDF as `powerbi/road_safety_dashboard.pdf`.
3. Take a screenshot of each page (**Windows key + Shift + S**). Save them as `powerbi/screenshots/overview.png`, `when.png`, `where.png` and `who.png`.

**Result:** a `.pbix` file (roughly 20–40 MB), a PDF and four PNG images.

> **Why the PDF and screenshots?** GitHub can't open `.pbix` files in the browser. Recruiters will look at the screenshots in the README, and the PDF lets them see the whole dashboard.

### Step 14: Show the dashboard in the README
Open `README.md` and find the **Dashboard** section. Remove the `<!--` and `-->` lines around the image links so the screenshots appear. Then push the changes:
```
git add .
git commit -m "Add Power BI dashboard"
git push
```

**Result:** your GitHub README shows the dashboard screenshots.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| The cards show numbers much bigger than expected | A relationship is wrong or missing. Check Step 4. |
| The `KSI` total shows **(Blank)** | The `ksi_adjusted` column is Text. Change it to Decimal in Power Query (**Transform data**). |
| `SAMEPERIODLASTYEAR` gives an error | The Date table isn't marked as a date table (see the end of Step 3). |
| Days show Friday, Monday, Saturday... | Sort by column wasn't set (Step 5). |
| The file won't push to GitHub (over 100 MB) | Delete unused columns in Power Query, or leave the `.pbix` out and keep only the PDF and screenshots. |
