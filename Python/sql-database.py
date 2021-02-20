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
# db_password = 'wenjianraph'
# engine = create_engine('postgresql://postgres:{}@localhost/gender'.format(db_password))

# Pipeline ---------->

# Perform scraping
url = 'https://ideas.repec.org/e/pag127.html'
mysoup = scraper.setup_soup(url)

# Get paper details
paper_details = scraper.scrape_papers(mysoup)
personal_details = scraper.scrape_personal(mysoup)
df_paper = scraper.makedf_paper(paper_details)
df_personal = scraper.makedf_personal(personal_details)
# %%

# Create three tables - one for authors, one for papers, and one author-papers
paper_table = df_paper[['paper','year']].drop_duplicates().reset_index(drop=True)
paper_table['paper_id'] = np.arange(paper_table.shape[0]) # Dependent on max number from database

author_table = df_paper[['author']].drop_duplicates().reset_index(drop=True)
author_table['author_id'] = np.arange(author_table.shape[0])
author_table['author'].split()
author_table = pd.merge
author_table['author_id'] = 0 # Dependent on max number from database
author_table['repec_url'] = url


#%%