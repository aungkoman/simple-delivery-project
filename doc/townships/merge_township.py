# pip install pandas
import pandas as pd

# 1. Load the three CSV files
states_df = pd.read_csv('MMCB Master Tables.docx-EmbeddedFile.xlsx - States_Region.csv')
districts_df = pd.read_csv('MMCB Master Tables.docx-EmbeddedFile.xlsx - Districts.csv')
townships_df = pd.read_csv('MMCB Master Tables.docx-EmbeddedFile.xlsx - Townships.csv')

# 2. Isolate the columns we want to bring over (Myanmar names)
# We only need the Pcodes to join on, and the Myanmar names to add to our final table.
states_mya = states_df[['SR_Pcode', 'State_Region_Mya_MM3']]
districts_mya = districts_df[['D_Pcode', 'District_Mya_MM3']]

# 3. Merge Townships with Districts to get District_Mya_MM3
merged_df = pd.merge(townships_df, districts_mya, on='D_Pcode', how='left')

# 4. Merge the result with States to get State_Region_Mya_MM3
final_df = pd.merge(merged_df, states_mya, on='SR_Pcode', how='left')

# 5. Clean up and reorder the columns logically (State -> District -> Township)
columns_order = [
'TS_Pcode', 'Township', 'Township_Mya_MM3',
'D_Pcode', 'District', 'District_Mya_MM3',
'SR_Pcode', 'State_Region', 'State_Region_Mya_MM3',
'MYAINFO_TS_ID', 'Source', 'Remark'
]
final_df = final_df[columns_order]

# 6. Export to a single flat CSV file
final_df.to_csv('supabase_locations_flat.csv', index=False)
print("Successfully created 'supabase_locations_flat.csv'")