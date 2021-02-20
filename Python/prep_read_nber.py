import pandas as pd
import numpy as np

def read_nber():
  papers = pd.read_table('http://www.nber.org/wp_metadata/title.txt', header = 0, lineterminator='\n', sep='\t')
  date = pd.read_table('http://www.nber.org/wp_metadata/date.txt', header = 0, lineterminator='\n', sep='\t')
  authors = pd.read_table('http://www.nber.org/wp_metadata/auths.txt', header = 0, lineterminator='\n', sep='\t')
  
  # Put into dataframes
  paper_date = pd.merge(left = papers, right = date, how = 'left', on='paper')
  # Those without date we put it as dated
  paper_date['issue_date'] = paper_date['issue_date'].replace('0000-00-00', '1999-09-09')
  paper_date['issue_date'] = pd.to_datetime(paper_date['issue_date'])
  # Get paper types
  paper_date['type'] = paper_date['paper'].str.get(0)
  # Filter out only working paper series
  wpaper = paper_date[paper_date['type']=='w'].reset_index(drop=True)
  df = pd.merge(left = wpaper, right = authors, how='left', on='paper')
  
  
  # NBER data needs jel and prog_areas
  # Combine JEL and PROG as well to the final table
  jel = pd.read_table('http://www.nber.org/wp_metadata/jel.txt', header = 0, lineterminator='\n', sep='\t')
  prog = pd.read_table('http://www.nber.org/wp_metadata/prog.txt', header = 0, lineterminator='\n', sep='\t')
  
  jel['jel_combined'] = jel.groupby('paper')['jel'].transform(lambda x: ', '.join(x))
  jel = jel[['paper','jel_combined']].drop_duplicates().reset_index(drop=True)
  prog['prog_combined'] = prog.groupby('paper')['program'].transform(lambda x: ', '.join(x))
  prog = prog[['paper','prog_combined']].drop_duplicates().reset_index(drop=True)
  
  # Merge with df
  nber_final = pd.merge(df, jel, on='paper', how='left')
  nber_final = pd.merge(nber_final, prog, on='paper', how='left')
  
  # Add details
  nber_final['outlet'] = 'nber'

  return nber_final
