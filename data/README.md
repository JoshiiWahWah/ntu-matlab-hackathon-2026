# Data

Place the WiDS Datathon 2022 files here (from the hackathon Telegram channel, or
https://www.kaggle.com/competitions/widsdatathon2022/data):

```
data/train.csv              75,757 rows, 64 columns (target: site_eui)
data/test.csv                9,705 rows, 63 columns (Year_Factor 7)
data/sample_solution.csv     submission template (included)
```

The raw CSVs are not committed (Kaggle data terms). `loadData.m` checks the
schema and the id order and stops with a clear message if something is off.
