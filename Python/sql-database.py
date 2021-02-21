#%%
import pandas as pd
import numpy as np
import psycopg2
import os
from sqlalchemy import create_engine
from tqdm import tqdm_notebook
import importlib

import prep_repecscraper as scraper
importlib.reload(scraper)

# Utilities ------------->


# # Create a database connection
db_password = 'wenjianraph'
engine = create_engine('postgresql://wenjian:{}@localhost/gender'.format(db_password))

# Pipeline ---------->

def create_paper_table(df_paper):
    paper_table = df_paper[['paper_url','paper','year']].drop_duplicates(subset=['paper']).reset_index(drop=True)
    paper_table['year'] = pd.to_numeric(paper_table['year'])

    # Write the data into the database
    paper_table.to_sql('paper_details', engine, if_exists='replace', index=False)

    # Create a primary key on the table
    query = """ALTER TABLE paper_details
                ADD PRIMARY KEY (paper_url);"""
    engine.execute(query)

    return print('created paper_details table!!')

def create_author_table(df_personal):

    # Write data into database
    df_personal.to_sql('author_details', engine, if_exists='replace', index=False)

    # Create a primary key on the table
    query = """ALTER TABLE author_details
                ADD PRIMARY KEY (first_name, last_name);"""
    engine.execute(query)

    return print('created author_details table!!')

def create_paper_author_table(df_paper):
    paper_author_table = df_paper[['paper_url','paper','author', 'first_name','last_name']].drop_duplicates()

        # Write data into database
    paper_author_table.to_sql('author_paper', engine, if_exists='replace', index=False)

    # Create a primary key on the table
    query = """ALTER TABLE author_paper
                ADD PRIMARY KEY (paper_url, first_name, last_name);"""
    engine.execute(query)

    return print('created paper_author table!!')


# Perform scraping
url = 'https://ideas.repec.org/e/pag127.html'
mysoup = scraper.setup_soup(url)

# Get paper details
paper_details = scraper.scrape_papers(mysoup)
personal_details = scraper.scrape_personal(mysoup)
df_paper = scraper.makedf_paper(paper_details)
df_personal = scraper.makedf_personal(personal_details)
df_paper = scraper.reconcile_first_name(df_paper, df_personal)
# df_paper = scraper.attach_abstract(df_paper)
# %%

create_author_table(df_personal)
create_paper_table(df_paper)
create_paper_author_table(df_paper)


#%%