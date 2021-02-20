# -*- coding: utf-8 -*-
# ---
# jupyter:
#   jupytext:
#     formats: ipynb,py:light
#     text_representation:
#       extension: .py
#       format_name: light
#       format_version: '1.5'
#       jupytext_version: 1.9.1
#   kernelspec:
#     display_name: Python 3.6(zeina)
#     language: python
#     name: zeina
# ---

# +
import numpy as np
import pandas as pd
import os
import pickle
import unicodedata
import operator
import unicodedata
import re
import datetime as dt
from serpapi.google_search_results import GoogleSearchResults

from pyagender import PyAgender
import cv2
from bs4 import BeautifulSoup
import requests
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.keys import Keys
import time
import base64
from genderize import Genderize
# -

os.chdir('..')

covid = pd.read_pickle('covid/covid_clean_winter.pickle')
cepr = pd.read_pickle('cepr/cepr_cleaned_winter.pickle')
vox = pd.read_pickle('cepr/vox_cleaned_winter.pickle')
nber_people = pd.read_pickle('nber/affiliation_mined_results_final_winter.pickle')
nber_text = pd.read_pickle('nber/nber_clean_winter.pickle')

covid_search = covid[['first_name','last_name', 'gender','affiliation']].drop_duplicates()

# +
cepr_search = cepr[['first_name','last_name','affiliation']].drop_duplicates()
cepr_search['gender'] = None

#CARELESS MISTAKE change to vox
vox_search = vox[['first_name','last_name','affiliation']].drop_duplicates()
vox_search['gender'] = None
# -

# Combine nber outputs
nber = pd.merge(nber_text[['paper','title','issue_date','name','relevant_text']].rename({'name':'authors'},axis=1),
                nber_people, how='left')
nber['first_name'] = nber['authors'].str.split(' ').str[0]

nber.to_pickle('nber/nber_winter.pickle')

nber_search = nber[['first_name','last_name','aff_mined']].rename({'aff_mined':'affiliation'}, axis=1)
nber_search['gender'] = None

full_search = pd.concat([nber_search, vox_search, cepr_search, covid_search]).drop_duplicates().reset_index(drop=True)


def remove_special(string):
    string = string.replace('á', 'a')\
                 .replace('Á', 'A')\
                 .replace('à', 'a')\
                 .replace('ã', 'a')\
                 .replace('ä', 'a')\
                 .replace('å', 'a')\
                 .replace('é', 'e')\
                 .replace('è', 'e')\
                 .replace('ë', 'e')\
                 .replace('í', 'i')\
                 .replace('ì', 'i')\
                 .replace('ó', 'o')\
                 .replace('Ó', 'O')\
                 .replace('ò', 'o')\
                 .replace('Ò', 'O')\
                 .replace('ö', 'o')\
                 .replace('ô', 'o')\
                 .replace('ø', 'o')\
                 .replace('ú', 'u')\
                 .replace('ü', 'u')\
                 .replace('ç', 'c')\
                 .replace('ñ', 'n')\
                .replace('ş','s')\
                .replace('Ç','C')\
                .replace('ğ', 'g')\
                .replace('Ö', 'O')\
                .replace('É','E')\
                .replace('Ø','O')\
                .replace('Ł','L')\
                .replace('Ş','S')\
                .replace('Š','S')\
                .replace('ě','e')\
                .replace('ï','i')\
                .replace('š','s')\
                .replace('Æ','AE')\
                .replace('Ð','D')\
                .replace('Þ','TH')\
                .replace('ß','ss')\
                .replace('æ','ae')\
                .replace('ð','o')\
                .replace('þ','th')\
                .replace('Œ','OE')\
                .replace('œ','oe')\
                .replace('  ', ' ')\
                .replace('"', '')\
                .replace('.','')
    string = unicodedata.normalize('NFKD',string).encode('ascii', 'ignore').decode('ascii').lower().strip().title()
                
    return string


full_search['clean_name'] = full_search['first_name'] + ' ' + full_search['last_name']
full_search['clean_name'] = full_search['clean_name'].apply(str).apply(remove_special)

# Previous dataset
previous = pd.read_csv('Output/full_dataset 2.csv')

check = pd.merge(full_search, previous[['clean_name','affiliation_guess',
                                        'gender_guess','google_link1']], how='left', on='clean_name')

previous.columns

checkout = check[check[['gender_guess', 'google_link1']].isnull().any(1)].drop(
    ['gender_guess','google_link1'],axis=1).drop_duplicates().reset_index(drop=True)

checkout


# +
def search_google(search):
    params = {
      "api_key": "06cf3123eef09ce67fc88528c3cc7971f3651b8a5502a7d315c58e63875ce056",
      "engine": "google",
      "q": f"{search}",
      "location": "Austin, Texas, United States",
      "google_domain": "google.com",
      "gl": "us",
      "hl": "en",
    }

    client = GoogleSearchResults(params)
    results = client.get_dict()
    return results

def loop_search(searches):
    name_searched = []
    google_link1 = []
    google_link2 = []
    google_snippet1 = []
    google_snippet2 = []
    
    for search in searches:
        results = search_google(search)
        
        try:
            # Test for circuit breaker
            test = [results['organic_results'][0]['link'],
                   results['organic_results'][0]['snippet'],
                   results['organic_results'][1]['link'],
                   results['organic_results'][1]['snippet']]
            # Save the relevant results
            google_link1.append(results['organic_results'][0]['link'])
            google_snippet1.append(results['organic_results'][0]['snippet'])
            google_link2.append(results['organic_results'][1]['link'])
            google_snippet2.append(results['organic_results'][1]['snippet'])
            name_searched.append(search)
        except:
            print('Error:' + search)
            google_link1.append(None)
            google_snippet1.append(None)
            google_link2.append(None)
            google_snippet2.append(None)
            name_searched.append(search)
            
    result_dict = {'name_searched': name_searched,
                  'google_link1': google_link1,
                  'google_snippet1': google_snippet1,
                  'google_link2': google_link2,
                  'google_snippet2': google_snippet2}
    
    output = pd.DataFrame(result_dict)
    return output


# -

checkout['search_term'] = checkout['clean_name'] + ' ' + ' economics cv'

search_term = checkout['search_term']

start = loop_search(search_term[0:5])

start

# +
# Incrementally increase the searches until limit is reached
steps = 5
pos = 200

limit = 800
iterations = limit/steps

for i in range(120):
    
    to = pos + steps
    print(f'Run iteration {i} : Looking up names in position {pos} to {to}')
    step_results = loop_search(search_term[pos:to])
    start = pd.concat([start, step_results]).reset_index(drop=True)
    start.to_pickle('Output/affiliation_results_winter.pickle')
    
    pos = pos + steps
    iterations = iterations - 1
    print(f'Success! Change iterations to {iterations} and pos to {pos}')
# -

start = pd.read_pickle('Output/affiliation_results_winter.pickle')

start=start[5:]

start.drop_duplicates(inplace=True)

start.shape

final = pd.merge(checkout, start,how='left', left_on='search_term', right_on='name_searched')

final

final.to_pickle('Output/winter_google.pickle')

# Start from final
final = pd.read_pickle('Output/winter_google.pickle')


# +
def readb64(uri):
    encoded_data = uri.split(',')[1]
    nparr = np.fromstring(base64.b64decode(encoded_data), np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    return img

def get_gender(search_name, driver):
    agender = PyAgender() 
    wait = WebDriverWait(driver, 1)
    # Input address search
    input_address = wait.until(EC.visibility_of_element_located((By.NAME, 'q')))
    #input_address = driver.find_elements_by_xpath("//input[@name='store_input']")[0]
    input_address.clear()
    input_address.send_keys(search_name)
    input_address.send_keys(Keys.RETURN)

    # Save images and classify
    first = driver.find_elements_by_tag_name("img")
    results = []
    
    iterations = 0
    img_found = 0
    while (img_found < 3) & (iterations <10):

        image = first[iterations].get_attribute('src')
        if re.match('data:image/', image):
            decoded = readb64(image)
            face = agender.detect_genders_ages(decoded)

            if face:
                gender = face[0]['gender']
            else:
                gender = None

            results.append(gender)
        
            img_found = img_found +1
            iterations = iterations +1
#             print(f'Successfully parse image {iterations}')
            
        else:
            iterations = iterations +1
            

    # Get the list of male or female
    lst = ['male' if x<0.5 else 'female' for x in results if x is not None]

    # Get the mode
    def mode(lst):
        if lst.count('female') == lst.count('male'):
            return None
        else:
            return max(set(lst), key=lst.count)
    
    reveal_gender = mode(lst)
    
    return reveal_gender
# -

genderize = Genderize(
    user_agent='GenderizeDocs/0.0',
    api_key='ac0ffe988a4e003ed04b846cdff211b0',
    timeout=5.0)

autumn_gender = pd.DataFrame(genderize.get(final['first_name']))

autumn_gender

final_genderize = pd.concat([final.drop('gender', axis=1), autumn_gender], axis=1)

final_genderize.to_pickle('Output/winter_google_genderize.pickle')

# Start from final_genderize
final_genderize = pd.read_pickle('Output/winter_google_genderize.pickle')
final_genderize.columns

facial = final_genderize.loc[final_genderize['probability']<0.8,:].reset_index(drop=True)

facial['img_search'] = facial['clean_name'] + ' economics'

facial['img_search']

chromepath = r'./chromedriver'
url = r'https://images.google.com'
options = Options()
options.add_argument("start-maximized")
options.add_argument("disable-infobars")
options.add_argument("--disable-extensions")
driver = webdriver.Chrome(options=options, executable_path=chromepath)
driver.get(url)
driver.implicitly_wait(3)

# If reset, use this code
output = pd.read_pickle('Output/winter_img_search_results_gender.pickle')
genders = output['gender_img'].tolist()
names_looked = output['search_string'].tolist()

# Log things in a list
genders = list()
names_looked = list()

pos = 117 # Change pos here!!
#Search by image recognition
for i in facial.img_search[117:]: # Change pos here too!!
    
    # Get gender
    g = get_gender(i, driver)
    
    genders.append(g)
    names_looked.append(i)
    pos = pos +1
    output = pd.DataFrame({'search_string': names_looked, 'gender_img': genders})
    output.to_pickle('Output/winter_img_search_results_gender.pickle')
    
    print(f'results - {g} - {pos}')
    time.sleep(15)



# Combine all results
covid = pd.read_pickle('covid/covid_clean_winter.pickle')
cepr = pd.read_pickle('cepr/cepr_cleaned_winter.pickle')
vox = pd.read_pickle('cepr/vox_cleaned_winter.pickle')
nber = pd.read_pickle('nber/nber_winter.pickle')
previous = pd.read_csv('Output/full_dataset 2.csv')
final_genderize = pd.read_pickle('Output/winter_google_genderize.pickle')
img_gender = pd.read_pickle('Output/winter_img_search_results_gender.pickle')

final_genderize['search_string'] = final_genderize['clean_name'] + ' economics'

final_genderize=final_genderize.drop_duplicates()

final = pd.merge(final_genderize, img_gender, how='left')

img_gender.shape

img_gender = img_gender.drop_duplicates()

final['gender_guess'] = np.where(final['gender_img'].isna(), final['gender'], final['gender_img'])

final

covid.columns

cepr.columns

vox.columns

nber.columns

previous.columns

# +
# NBER data needs jel and prog_areas
# Combine JEL and PROG as well to the final table
jel = pd.read_table('http://www.nber.org/wp_metadata/jel.txt', header = 0, lineterminator='\n', sep='\t')

prog = pd.read_table('http://www.nber.org/wp_metadata/prog.txt', header = 0, lineterminator='\n', sep='\t')

jel['jel_combined'] = jel.groupby('paper')['jel'].transform(lambda x: ', '.join(x))

jel = jel[['paper','jel_combined']].drop_duplicates().reset_index(drop=True)

prog['prog_combined'] = prog.groupby('paper')['program'].transform(lambda x: ', '.join(x))
prog = prog[['paper','prog_combined']].drop_duplicates().reset_index(drop=True)



# +
nber_final = pd.merge(nber, jel, on='paper', how='left')

nber_final = pd.merge(nber_final, prog, on='paper', how='left')
# -

nber_final.columns

nber_details = nber_final.rename({'paper':'paper_code',
                  'issue_date':'date',
                  'authors':'original_name',
                  'url':'nber_homepage',
                  'aff_mined':'affiliation_guess',
                  'jel_combined':'jel','prog_combined':'prog_areas'}, axis=1).drop('links', axis=1)

all_cols_paper = ['outlet', 'title', 'paper_code', 'jel', 'prog_areas', 'original_name',
                   'first_name', 'last_name', 'clean_name', 'date', 'relevant_text', 'paper_link',
                    'nber_homepage', 'nber_subscription', 'affiliation_guess', 'position_guess', 'covid_decision']

all_cols_details = ['probability_io', 'count_io', 'gender_io', 'gender_img','gender_guess',
                   'google_link1', 'google_snippet1',
                   'google_link2', 'google_snippet2',]

nber_details['outlet'] = 'nber'
nber_details['clean_name'] = nber_details['first_name'] + ' ' + nber_details['last_name']
nber_details['paper_link'] = 'https://www.nber.org/papers/' + nber_details['paper_code']

nber_details.columns

covid_details = covid.rename({'gender':'gender_included', 
              'affiliation':'affiliation_guess', 
              'title':'title', 
              'date':'date', 
              'decision':'covid_decision', 
              'author':'original_name',
       'last_name':'last_name', 'first_name':'first_name'}, axis=1).drop('lead_author', axis=1)

covid_details['outlet'] = 'covid'
covid_details['clean_name'] = covid_details['first_name'] + ' ' + covid_details['last_name']

cepr_details = cepr.rename({'dp_no':'paper_code', 
                            'author':'original_name', 
                            'affiliation':'affiliation_guess',
                           'jel_codes':'jel', 'url':'paper_link'},axis=1).drop('date_revised',axis=1)

cepr_details['outlet'] = 'cepr'
cepr_details['clean_name'] = cepr_details['first_name'] + ' ' + cepr_details['last_name']

vox_details = vox.rename({'url':'paper_link', 'author':'original_name',  
                          'position':'position_guess',
                           'affiliation':'affiliation_guess'}, axis=1).drop('affiliation_complete',
                                                                                              axis=1)

vox_details['outlet'] = 'vox'
vox_details['first_name'] = vox_details['first_name'].str.split(' ').str[0]
vox_details['last_name'] = vox_details['last_name'].str.split(' ').str[-1]
vox_details['clean_name'] = vox_details['first_name'] + ' ' + vox_details['last_name']

vox_details.columns

combined = pd.concat([nber_details, covid_details, cepr_details, vox_details], axis=0).reset_index(drop=True)

combined

combined['clean_name'] = combined['clean_name'].apply(remove_special)

previous_extract = previous[['clean_name','gender_io',
       'probability_io', 'count_io', 'gender_img','gender_guess',
         'google_link1', 'google_snippet1',
       'google_link2', 'google_snippet2']].add_prefix('previous_')

previous_extract = previous_extract.rename({'previous_clean_name':'clean_name'},axis=1)

previous_extract.columns

previous_extract['previous_dummy'] = 'previous'

previous_extract.drop_duplicates(subset = ['clean_name'], inplace=True)

combined_previous = pd.merge(combined, previous_extract, on=['clean_name'], how='left')

combined.shape

combined_previous.shape

combined_previous

final_extract = final.drop(['first_name','last_name','search_term','name_searched', 'name','search_string',
                           'affiliation'], axis=1).rename(
{'gender':'gender_io', 'probability':'probability_io', 'count':'count_io'}, axis=1).add_prefix('new_').rename(
    {'new_clean_name':'clean_name'},axis=1).drop_duplicates(
subset = ['clean_name'])

final_extract['new_dummy'] = 'new'

combined_final = pd.merge(combined_previous, final_extract, on=['clean_name'], how='left')

combined_final.columns

combined_final['merge_dummy'] = np.where(combined_final[['previous_dummy','new_dummy']].isna().all(axis=1), 'no results',
                                        np.where((combined_final['previous_dummy'].isna() & combined_final['new_dummy'].notnull()), 
                                                combined_final['new_dummy'],
                                                np.where((combined_final['previous_dummy'].notnull() & combined_final['new_dummy'].isna()),
                                                        combined_final['previous_dummy'], 'overlap')))

combined_final['merge_dummy'].value_counts()

combined_final.loc[combined_final['merge_dummy']=='no results',:].outlet

combined_final = combined_final.loc[combined_final['clean_name']!='',:]

combined_final.shape

vox_redo = combined_final.loc[combined_final['merge_dummy'] == 'no results',:].reset_index(drop=True)

vox_redo.shape

search_term = vox_redo['original_name'] + ' ' + 'economics cv'

start = loop_search(search_term[0:5])

# +
# Incrementally increase the searches until limit is reached
steps = 5
pos = 5

limit = 15
iterations = limit/steps

for i in range(3):
    
    to = pos + steps
    print(f'Run iteration {i} : Looking up names in position {pos} to {to}')
    step_results = loop_search(search_term[pos:to])
    start = pd.concat([start, step_results]).reset_index(drop=True)
    start.to_pickle('Output/vox_redo_winter.pickle')
    
    pos = pos + steps
    iterations = iterations - 1
    print(f'Success! Change iterations to {iterations} and pos to {pos}')
# -

start['name_searched'] = start['name_searched'].str.replace(' economics cv','')

vox_redo_gender = pd.DataFrame(genderize.get(vox_redo['first_name']))

vox_redo_gender

vox_answers = pd.concat([start,vox_redo_gender], axis=1)

vox_redo.columns

vox_replace = vox_answers.drop(['name_searched','name'],axis=1).add_prefix('new_').rename({'new_gender':'new_gender_io',
                                                                     'new_probability':'new_probability_io',
                                                                     'new_count':'new_count_io'},axis=1)

vox_replace.columns

vox_redo = vox_redo.drop(['new_google_link1', 'new_google_snippet1', 'new_google_link2',
       'new_google_snippet2', 'new_gender_io', 'new_probability_io',
       'new_count_io'],axis=1)

vox_redo = pd.concat([vox_redo, vox_replace], axis=1)

vox_redo['merge_dummy'] = 'new'

combined_final.loc[combined_final['merge_dummy'] == 'no results',:] = vox_redo

combined_final['merge_dummy'].value_counts()

combined_final = combined_final.loc[combined_final['original_name'].notna(),:].reset_index(drop=True)

combined_final.shape

combined_final.to_csv('Output/winter_combined.csv')


