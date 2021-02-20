# %%
import pandas as pd
import numpy as np
import requests
import unicodedata
import re
from fuzzywuzzy import fuzz, process
from bs4 import BeautifulSoup

url = 'https://ideas.repec.org/e/pag127.html'

# ----------- UTILITY ---------------
def clean_string(string):
    string = unicodedata.normalize('NFKD',string) \
        .encode('ascii', 'ignore') \
        .decode('ascii') \
        .lower() \
        .strip() \
        .title()
    return string

def clean_series(series):
    cleaned = series.map(clean_string)
    return cleaned

# PIPELINE ----------------->
# Set up soup
def setup_soup(url):
    # Setup beautiful soup
    page = requests.get(url)
    soup = BeautifulSoup(page.content, 'html.parser')
    return soup

# Scrape papers information from the author
def scrape_papers(soup):
    # Publication classifications free, gate, none
    # There will be overlaps
    publications = soup.find_all('li', class_={'list-group-item downfree', \
        'list-group-item downgate', 'list-group-item downnone'})

    paper_details = {}
    for pub in publications:
        title = pub.find('a').text
        name_year = pub.text.strip().split('\n')[0]
        authors = re.sub(r', \d{4}\.', '',name_year).split(' & ')
        year = int(re.findall(r', (\d{4})\.', name_year)[0])
        paper_details[title] = {'url':url, 'author': authors, 'year': year}

    return paper_details

# Scraping personal information of the author
def scrape_personal(soup):
    # Find portion where personal details lie in
    personal_details = soup.find('tbody').find_all('tr')

    # Set up a dictionary to collect all personal information
    per = {}
    for p in personal_details:
        k = p.find_all('td')[0].text.replace(':','')
        v = p.find_all('td')[1].text.strip()
        per[k] = v
    
    per_clean = {k:v for (k,v) in per.items() if (v is not '') }

    # Find homepage link
    try:    
        homepage = soup.find('td', {'class':'homelabel'}).next_sibling.find('a', href=True)['href']
        per_clean['Homepage'] = homepage
    except:
        print('homepage not found')

    # Find affiliation - can have multiple
    affiliation_soup = soup.find('div', {'id':'affiliation'})
    i = 0
    try:
        for a in affiliation_soup.find_all('h3'):
            if a.find('br'):
                department = a.find('br').previous_sibling
                organisation = a.find('br').next_sibling
            else:
                print('no breaks in affiliation')
                department = ''
                organisation = a
            per_clean['Aff_Department{}'.format(i)] = department
            per_clean['Aff_Organisation{}'.format(i)] = organisation
            i += 1
    except:
        print('affiliation not found')

    # Find affiliation locations - can have multiple
    i = 0
    try:
        for a in affiliation_soup.find_all('span', {'class':'locationlabel'}):
            if a:
                location = a.text
            else:
                print('no location in affiliation')
            per_clean['Aff_Location{}'.format(i)] = location
            i += 1
    except:
        print('affiliation not found')

    return per_clean

# Flatten the paper details into a dataframe to be inserted into database
def makedf_paper(paper_details):
    # Flatten the paper_details dictionary into a pandas dataframe
    pd_paperdetails = pd.DataFrame(paper_details) \
        .transpose() \
        .explode('author') \
        .explode('url') \
        .reset_index() \
        .rename(columns = {'index':'paper'})
    
    # Make capitalise titles
    pd_paperdetails[['paper','author']] = pd_paperdetails[['paper','author']] \
        .apply(clean_series, axis=1)

    # Drop duplicates
    pd_paperdetails = pd_paperdetails.drop_duplicates(
        subset = ['paper', 'author'])
    
    # Drop titles that are very similar
    similar = process.dedupe(list(pd_paperdetails['paper'].unique()), threshold = 95)
    pd_paperdetails = pd_paperdetails[pd_paperdetails['paper'].isin(similar)]
   
   # Convert 
    return pd_paperdetails


# %%
