import pandas as pd
import os
import re
import glob

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
BACKEND_DIR = os.path.dirname(SCRIPT_DIR)
DATA_DIR = os.path.join(BACKEND_DIR, "data")

# 🔥 THE ROUTER: Enterprise Geocoding for Kenyan Markets & ASAL regions
TOWN_TO_COUNTY = {
    "nairobi": "nairobi", "dandora": "nairobi", "kangemi": "nairobi", "kawangware": "nairobi", 
    "mathare": "nairobi", "wakulima_nairobi": "nairobi", "kibra": "nairobi", "mukuru": "nairobi", 
    "kiwanja": "nairobi", "shauri_yako": "nairobi",
    "mombasa": "mombasa", "junda": "mombasa", "shonda": "mombasa", "kalahari": "mombasa", 
    "kongowea": "mombasa", "vanga": "kwale", "kilifi": "kilifi", "matanomanne": "kilifi",
    "nakukulas": "turkana", "lowarengak": "turkana", "katilia": "turkana", "urum": "turkana", 
    "kaakelai": "turkana", "kokuro": "turkana", "kaleng": "turkana", "elelea": "turkana", 
    "lokichoggio": "turkana", "loturerei": "turkana", "nakinomet": "turkana", "lokitaung": "turkana", 
    "eliye": "turkana", "lodwar": "turkana", "lokwii": "turkana", "kalemunyang": "turkana", 
    "kakuma_3": "turkana", "kataboi": "turkana", "lorengipi": "turkana", "lororo": "turkana", 
    "lokiriama": "turkana", "lokori": "turkana", "todonyang": "turkana", "lokichar": "turkana", 
    "kalokol": "turkana", "lolupe": "turkana", "namoruputh": "turkana", "letea": "turkana", 
    "lokapel": "turkana", "lorugum": "turkana", "kaeris": "turkana", "naduat": "turkana", 
    "lopur": "turkana", "kakuma_2": "turkana", "turkwel": "turkana", "kalemgorok": "turkana", 
    "alemsekon": "turkana", "kakuma_4": "turkana", "kakuma": "turkana", "naakalei": "turkana", 
    "kaikor": "turkana", "kalobeyei": "turkana", "lokangae": "turkana", "kibish": "turkana",
    "garissa": "garissa", "benane": "garissa", "ifo": "garissa", "malka_galla": "garissa", 
    "modogashe": "garissa", "shanta_abak": "garissa", "dadaab": "garissa", "alinjugur": "garissa", 
    "jarajara": "garissa", "korakora": "garissa", "boka": "garissa", "saretho": "garissa", 
    "dagahaley": "garissa", "liboi": "garissa", "dertu": "garissa", "damajale": "garissa", 
    "saka": "garissa", "hagadera": "garissa", "hara": "garissa",
    "wajir": "wajir", "habaswein": "wajir", "tarbaj": "wajir", "griftu": "wajir", 
    "lagbogol": "wajir", "hadado": "wajir", "eldas": "wajir", "buna": "wajir", 
    "alango_arba": "wajir", "bute": "wajir",
    "mandera": "mandera", "banissa": "mandera", "ashabito": "mandera", "rhamu": "mandera", 
    "el_wak": "mandera", "takaba": "mandera", "warankara": "mandera", "alungu": "mandera", "kiliwaheri": "mandera",
    "minjila": "tana_river", "boji": "tana_river", "charidende": "tana_river", "waldena": "tana_river", 
    "kipini": "tana_river", "makere": "tana_river", "wayu": "tana_river", "hola": "tana_river", 
    "nanigi": "tana_river", "tarasaa": "tana_river", "garsen": "tana_river", "bura": "tana_river", 
    "bangale": "tana_river", "bilbil": "tana_river", "maalamin": "tana_river", "masikita": "tana_river",
    "marsabit": "marsabit", "moyale": "marsabit", "loglogo": "marsabit", "karare": "marsabit", 
    "korr": "marsabit", "maikona": "marsabit", "kargi": "marsabit", "dirib": "marsabit", 
    "merille": "marsabit", "laisamis": "marsabit", "loyangalani": "marsabit", "songa": "marsabit", 
    "ngurunit": "marsabit", "kargi_south_horr": "marsabit", "north_horr": "marsabit", "dub_goba": "marsabit",
    "isiolo": "isiolo", "merti": "isiolo", "ngaremara": "isiolo", "garbatulla": "isiolo", 
    "malkadaka": "isiolo", "sericho": "isiolo", "bulesa_bulesa": "isiolo", "biliqo": "isiolo", 
    "kipsing": "isiolo", "iresaboru": "isiolo", "oldonyiro": "isiolo",
    "baragoi": "samburu", "lpus": "samburu", "archers_post": "samburu", "porro": "samburu", 
    "lolkuniyani": "samburu", "suguta": "samburu", "kisima": "samburu", "wamba": "samburu", 
    "ngilai": "samburu", "nachola": "samburu", "lengusaka": "samburu", "lodungokwe": "samburu", 
    "lolkunono": "samburu", "loosuk": "samburu", "maralal": "samburu", "lesirkan": "samburu",
    "marigat": "baringo", "chemolingot": "baringo", "loboi": "baringo", "nginyang": "baringo", 
    "lotubae": "baringo", "simale": "baringo", "lomut": "west_pokot", "makutano": "west_pokot",
    "makueni": "makueni", "kibwezi": "makueni", "mtito_andei": "makueni", "wote": "makueni", 
    "emali": "makueni", "kathonzweni": "makueni", "tala": "machakos", "kajiado": "kajiado", 
    "illbissil_food": "kajiado", "kitengela": "kajiado",
    "nakuru": "nakuru", "wakulima_nakuru": "nakuru", "eldoret": "uasin_gishu", "trans-nzoia": "trans_nzoia",
    "kisumu": "kisumu", "kibuye": "kisumu", "kisumu_ndogo": "kisumu", "kakamega": "kakamega",
    "karatina": "nyeri", "meru": "meru", "kitui": "kitui", "kirinyaga": "kirinyaga", "kaanwa": "tharaka_nithi",
    "bomet": "bomet", "aposta": "unknown_asal", "baraki": "unknown_asal"
}

def clean_string(text: str) -> str:
    text = re.sub(r'\(.*?\)', '', str(text))
    return text.strip().lower()

def clean_market_name(name: str) -> str:
    name = str(name).lower().strip()
    if 'wakulima' in name and 'nairobi' in name: return 'wakulima_nairobi'
    if 'wakulima' in name and 'nakuru' in name: return 'wakulima_nakuru'
    name = re.sub(r'\(.*?\)', '', name).strip()
    name = name.replace('_town', '').replace(' town', '')
    name = name.replace('_market', '').replace(' market', '')
    name = name.replace('_centre', '').replace(' centre', '')
    name = name.replace(' center', '')
    return name.strip()

def build_enterprise_datasets():
    print("⏳ [Phase 1] Scrubbing & Geofencing WFP baseline data...")
    wfp_path = os.path.join(BACKEND_DIR, "scripts", "wfp_food_prices_ken.csv")
    
    master_frames = []
    
    if os.path.exists(wfp_path):
        df_wfp = pd.read_csv(wfp_path)
        df_wfp.rename(columns={'date': 'ds'}, inplace=True)
        df_wfp['commodity'] = df_wfp['commodity'].apply(clean_string)
        df_wfp['pricetype'] = df_wfp['pricetype'].apply(clean_string)
        df_wfp['market'] = df_wfp['market'].apply(clean_market_name)
        
        banned_markets = ['mogadishu', 'ethiopia', 'hongkong', 'bangladesh', 'moroto', 'napak']
        df_wfp = df_wfp[~df_wfp['market'].isin(banned_markets)]
        
        excluded_items = ['fuel', 'milk', 'oil', 'bread', 'meat', 'sugar', 'salt']
        df_wfp = df_wfp[~df_wfp['commodity'].str.contains('|'.join(excluded_items))]

        df_wfp['unit_weight'] = df_wfp['unit'].str.extract(r'(\d+)').astype(float).fillna(1.0)
        df_wfp['price'] = df_wfp['price'] / df_wfp['unit_weight']
        
        master_frames.append(df_wfp[['ds', 'market', 'commodity', 'pricetype', 'price']])

    print("⏳ [Phase 2] Salvaging KAMIS scraped data before wipe...")
    if os.path.exists(DATA_DIR):
        scraped_files = glob.glob(os.path.join(DATA_DIR, "*.csv"))
        for file in scraped_files:
            try:
                df_kamis = pd.read_csv(file)
                if 'market' in df_kamis.columns and 'price' in df_kamis.columns:
                    master_frames.append(df_kamis[['ds', 'market', 'commodity', 'pricetype', 'price']])
            except Exception as e:
                print(f"Skipping {file}: {e}")

    if not master_frames:
        print("❌ No data found at all!")
        return

    print("🌍 [Phase 3] Merging and mapping all markets to true Counties...")
    df_master = pd.concat(master_frames, ignore_index=True)
    
    # Apply the dictionary to find the real County, fallback to original name if missing
    df_master['true_county'] = df_master['market'].apply(lambda x: TOWN_TO_COUNTY.get(x, x))
    
    print("🧹 [Phase 4] Wiping old fragmented data files...")
    if os.path.exists(DATA_DIR):
        for file in os.listdir(DATA_DIR):
            os.remove(os.path.join(DATA_DIR, file))
    os.makedirs(DATA_DIR, exist_ok=True)
    
    print("💾 [Phase 5] Saving Master County Databases...")
    valid_counties = df_master['true_county'].unique()
    
    for county in valid_counties:
        county_df = df_master[df_master['true_county'] == county]
        
        # Sort by date and drop exact duplicates (e.g. if KAMIS scraped the same day twice)
        county_df = county_df.sort_values(by='ds')
        county_df.drop_duplicates(subset=['ds', 'commodity', 'pricetype'], keep='last', inplace=True)
        
        final_df = county_df[['ds', 'price', 'commodity', 'pricetype']].dropna()
        if len(final_df) < 1: continue # We removed the AI limit, save everything!
        
        safe_county_name = county.replace(" ", "_")
        file_path = os.path.join(DATA_DIR, f"master_{safe_county_name}.csv")
        final_df.to_csv(file_path, index=False)
        
    print(f"✅ Master Datasets built successfully in: {DATA_DIR}")

if __name__ == "__main__": 
    build_enterprise_datasets()