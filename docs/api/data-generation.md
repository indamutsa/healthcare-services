## 🖥️ **Command Line Argument Usage**

**Command line** arguments that can be passed in when running the Python script.

**Basic syntax:**

```bash
python clinical_data_generator.py [OPTIONS]
```

## 📝 **Argument Examples**

**1. Run with default settings** (infinite messages, 1-5 second intervals):

```bash
python clinical_data_generator.py
```

**2. Generate exactly 10 messages:**

```bash
python clinical_data_generator.py --count 10
```

**3. Change the interval to 2-8 seconds:**

```bash
python clinical_data_generator.py --interval 2-8
```

**4. Point to a different endpoint:**

```bash
python clinical_data_generator.py --endpoint http://localhost:9080
```

**5. Enable verbose logging:**

```bash
python clinical_data_generator.py --verbose
# or short version:
python clinical_data_generator.py -v
```

**6. Combine multiple arguments:**

```bash
python clinical_data_generator.py --count 20 --interval 3-7 --verbose --endpoint http://localhost:8080
```

## 🔧 **Real Demo Examples**

**Quick test run** (good for initial testing):

```bash
python clinical_data_generator.py --count 5 --interval 1-2 --verbose
```

**Interview demo** (continuous, realistic pacing):

```bash
python clinical_data_generator.py --interval 3-8 --verbose
```

**Fast demo** (show lots of data quickly):

```bash
python clinical_data_generator.py --count 50 --interval 1-1
```

**Production simulation** (slower, more realistic):

```bash
python clinical_data_generator.py --interval 10-30 --endpoint http://production-server:8080
```

## 🎛️ **How argparse Works**

**Think of it like a restaurant order analogy:**

```python
# This is like defining the menu options
parser.add_argument('--count', type=int, default=0)

# When customer orders: "I'll take 10 messages please"
# Command line: --count 10
# Code receives: args.count = 10
```

**In your script:**

```python
# These lines parse what the user typed
args = parser.parse_args()

# Now you can use the values
if args.verbose:
    logging.getLogger().setLevel(logging.DEBUG)

min_interval, max_interval = map(int, args.interval.split('-'))
```

## 💡 **Pro Tips for Your Interview Demo**

**1. Show help documentation:**

```bash
python clinical_data_generator.py --help
```

**2. Start with a test run:**

```bash
python clinical_data_generator.py --count 3 --verbose
```

**3. Then show continuous generation:**

```bash
python clinical_data_generator.py --interval 2-5 --verbose
```

**4. Explain the flexibility:**

```
"Notice how I can configure the data generation rate and volume
without changing code - this makes it perfect for different
demo scenarios or load testing environments."
```

## 🔄 **Demo Flow Sequence**

1. **First:** `--count 5 --verbose` (show data structure)
2. **Then:** `--count 20 --interval 1-2` (show volume)
3. **Finally:** `--interval 3-10` (realistic demo pace)
