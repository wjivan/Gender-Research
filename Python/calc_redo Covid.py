import pandas as pd
import numpy as np
import pickle
import os
import re

# Read in latest data
covid = pd.read_excel('Input/covid paper info for Elisa_clean.xlsx', sheet_name='4th dataset')

# Pivot wider for co-authors
wider = pd.concat([covid.drop('Co-authors',axis=1),covid['Co-authors'].str.split(", ", expand=True).add_prefix('author')],axis=1)

# Find how many co-authors +1 for main author
string = ''.join(wider.columns)
pos = int(max(re.findall(r'author([0-9]+)', string))) +1

wider['author'+ str(pos)]=wider['Forename']+' '+wider['Surname']
wider.drop(['Forename','Surname'], axis=1, inplace=True)
author_cols = [cols for cols in wider.columns if cols.startswith('author')]
id_vars = [cols for cols in wider.columns if not cols.startswith('author')]

longer = wider.melt(id_vars=id_vars, value_vars=author_cols, value_name='author').dropna(subset=['author']).drop('variable',axis=1)

# Gender, Institution, paper titles are for lead authors
lead_author = covid.iloc[:,0:3]
lead_author['lead_author'] = lead_author['Forename'] + ' ' + lead_author['Surname']

lead_author.drop(columns = ['Forename', 'Surname']).rename(columns={"Unnamed: 0":"gender"})

new = pd.concat([longer.drop('author',axis=1), 
                longer['author'].str.split(' and ', expand=True).add_prefix('author')], axis=1)

# +
author_cols = [cols for cols in new.columns if cols.startswith('author')]

id_vars = [cols for cols in new.columns if not cols.startswith('author')]


# -

new = new.melt(id_vars=id_vars, value_vars=author_cols, value_name = 'author').dropna(subset=['author']).drop(
    'variable',axis=1)

new['author'] = new['author'].str.strip()

new.shape

new.drop_duplicates(inplace=True)

new.shape

new.columns = ['gender','affiliation', 'title', 'date', 'decision', 'author']

new.columns

new.reset_index(drop=True, inplace=True)

new['last_name'] = new['author'].str.split(' ').str[-1]
new['first_name'] = new['author'].str.split(' ').str[0]

new

new['gender'] = np.where(new['gender']=='M', 'male', 
                                      np.where(new['gender']=='F', 'female', None))

new

covid['lead_author']=1

covid['author'] = covid['Forename']+ ' ' +covid['Surname']

indicator = covid[['author','Paper Title','lead_author']]

indicator.columns = ['author','title','lead_author']

new = pd.merge(left=new, right=indicator, how='left')

new['affiliation'] = np.where(new['lead_author'].isna(), None, new['affiliation'])

new

new.to_pickle('covid/covid_clean_winter.pickle')


