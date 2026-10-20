from pathlib import Path
from PIL import Image, ImageOps
import numpy as np
import json


ROOT = Path(__file__).resolve().parents[1]
DATASET = ROOT / "dataset_extracted" / "dataset"
SRC = ROOT / "project_1.srcs" / "sources_1" / "new"
OUT = ROOT / "trained_model"
IMG_SIZE = 28
INPUTS = 28 * 28 * 3
H1 = 64
H2 = 32
W_SCALE = 64
SHIFT = 8


def load_images():
    xs, ys, paths = [], [], []
    for label, name in [(0, "cat"), (1, "dog")]:
        folder = DATASET / name
        for path in sorted(folder.glob("*")):
            if path.suffix.lower() not in [".jpg", ".jpeg", ".png", ".bmp", ".webp"]:
                continue
            try:
                img = Image.open(path).convert("RGB")
                img = ImageOps.fit(img, (IMG_SIZE, IMG_SIZE), method=Image.Resampling.LANCZOS)
                arr = np.asarray(img, dtype=np.int16).reshape(-1) - 128
                xs.append(arr.astype(np.int8))
                ys.append(label)
                paths.append(str(path.relative_to(ROOT)))
            except Exception as exc:
                print(f"Skipping {path}: {exc}")
    x_int = np.stack(xs).astype(np.int16)
    x = x_int.astype(np.float32) / 128.0
    y = np.array(ys, dtype=np.float32).reshape(-1, 1)
    return x, x_int, y, paths


def augment_image_array(arr, rng):
    img = arr.reshape(IMG_SIZE, IMG_SIZE, 3).astype(np.float32) + 128.0
    if rng.random() < 0.5:
        img = img[:, ::-1, :]
    scale = rng.uniform(0.85, 1.15)
    offset = rng.uniform(-18.0, 18.0)
    img = (img - 128.0) * scale + 128.0 + offset
    if rng.random() < 0.35:
        noise = rng.normal(0.0, 8.0, size=img.shape)
        img = img + noise
    img = np.clip(img, 0, 255)
    return (img.reshape(-1).astype(np.int16) - 128).astype(np.int16)


def build_augmented_training_set(x_int, y, train_idx, copies, seed):
    rng = np.random.default_rng(seed)
    xs = [x_int[train_idx]]
    ys = [y[train_idx]]
    for _ in range(copies):
        aug = np.stack([augment_image_array(x_int[i], rng) for i in train_idx])
        xs.append(aug)
        ys.append(y[train_idx])
    x_aug_int = np.concatenate(xs, axis=0).astype(np.int16)
    y_aug = np.concatenate(ys, axis=0).astype(np.float32)
    x_aug = x_aug_int.astype(np.float32) / 128.0
    return x_aug, x_aug_int, y_aug


def relu(x):
    return np.maximum(x, 0)


def sigmoid(x):
    return 1.0 / (1.0 + np.exp(-np.clip(x, -40, 40)))


def forward(x, p):
    z1 = x @ p["w1"] + p["b1"]
    a1 = relu(z1)
    z2 = a1 @ p["w2"] + p["b2"]
    a2 = relu(z2)
    z3 = a2 @ p["w3"] + p["b3"]
    return z1, a1, z2, a2, z3


def train(x, y, train_idx, val_idx, seed=7, epochs=700):
    rng = np.random.default_rng(seed)
    p = {
        "w1": (rng.standard_normal((INPUTS, H1)) * np.sqrt(2 / INPUTS)).astype(np.float32),
        "b1": np.zeros((H1,), dtype=np.float32),
        "w2": (rng.standard_normal((H1, H2)) * np.sqrt(2 / H1)).astype(np.float32),
        "b2": np.zeros((H2,), dtype=np.float32),
        "w3": (rng.standard_normal((H2, 1)) * np.sqrt(2 / H2)).astype(np.float32),
        "b3": np.zeros((1,), dtype=np.float32),
    }
    m = {k: np.zeros_like(v) for k, v in p.items()}
    v = {k: np.zeros_like(v) for k, v in p.items()}
    lr = 0.0015
    batch = 32
    best = None
    best_val = -1.0
    step = 0

    patience = 12
    stale = 0
    for epoch in range(1, epochs + 1):
        rng.shuffle(train_idx)
        for start in range(0, len(train_idx), batch):
            idx = train_idx[start:start + batch]
            xb, yb = x[idx], y[idx]
            z1, a1, z2, a2, z3 = forward(xb, p)
            pred = sigmoid(z3)
            dz3 = (pred - yb) / len(idx)
            grads = {}
            grads["w3"] = a2.T @ dz3
            grads["b3"] = dz3.sum(axis=0)
            da2 = dz3 @ p["w3"].T
            dz2 = da2 * (z2 > 0)
            grads["w2"] = a1.T @ dz2
            grads["b2"] = dz2.sum(axis=0)
            da1 = dz2 @ p["w2"].T
            dz1 = da1 * (z1 > 0)
            grads["w1"] = xb.T @ dz1
            grads["b1"] = dz1.sum(axis=0)

            step += 1
            for k in p:
                grads[k] += 0.0010 * p[k]
                m[k] = 0.9 * m[k] + 0.1 * grads[k]
                v[k] = 0.999 * v[k] + 0.001 * (grads[k] * grads[k])
                mh = m[k] / (1 - 0.9 ** step)
                vh = v[k] / (1 - 0.999 ** step)
                p[k] -= lr * mh / (np.sqrt(vh) + 1e-8)

        if epoch % 25 == 0 or epoch == 1:
            _, _, _, _, tv = forward(x[train_idx], p)
            _, _, _, _, vv = forward(x[val_idx], p)
            train_acc = ((sigmoid(tv) >= 0.5) == y[train_idx]).mean()
            val_acc = ((sigmoid(vv) >= 0.5) == y[val_idx]).mean()
            print(f"seed {seed:2d} epoch {epoch:4d} train_acc={train_acc:.3f} val_acc={val_acc:.3f}")
            if val_acc >= best_val:
                best_val = float(val_acc)
                best = {k: val.copy() for k, val in p.items()}
                stale = 0
            else:
                stale += 1
            if epoch >= 150 and stale >= patience:
                break
    return best


def q8(a):
    return np.clip(np.round(a * W_SCALE), -128, 127).astype(np.int16)


def quantize(p):
    return {
        "w1": q8(p["w1"]),
        "b1": np.round(p["b1"] * 128 * W_SCALE).astype(np.int64),
        "w2": q8(p["w2"]),
        "b2": np.round(p["b2"] * 32 * W_SCALE).astype(np.int64),
        "w3": q8(p["w3"]),
        "b3": np.round(p["b3"] * 8 * W_SCALE).astype(np.int64),
    }


def int_infer(x_int, q):
    out = int_scores(x_int, q)
    return (out > 0).astype(np.float32)


def int_scores(x_int, q):
    h1_acc = x_int.astype(np.int64) @ q["w1"].astype(np.int64) + q["b1"]
    h1 = np.clip(h1_acc >> SHIFT, 0, 127).astype(np.int64)
    h2_acc = h1 @ q["w2"].astype(np.int64) + q["b2"]
    h2 = np.clip(h2_acc >> SHIFT, 0, 127).astype(np.int64)
    out = h2 @ q["w3"].astype(np.int64) + q["b3"]
    return out


def tune_output_bias(q, x_int, y, val_idx):
    tuned = {k: v.copy() for k, v in q.items()}
    scores = int_scores(x_int[val_idx], tuned)[:, 0]
    labels = y[val_idx, 0]
    candidates = np.unique(scores)
    best_acc = -1.0
    best_threshold = 0
    for threshold in candidates:
        pred = (scores > threshold).astype(np.float32)
        acc = float((pred == labels).mean())
        if acc > best_acc:
            best_acc = acc
            best_threshold = int(threshold)
    tuned["b3"] = tuned["b3"] - best_threshold
    return tuned, best_threshold, best_acc


def hex8(v):
    return f'x"{int(v) & 0xFF:02X}"'


def hex32(v):
    return f'x"{int(v) & 0xFFFFFFFF:08X}"'


def rom_values(values, width):
    fmt = hex8 if width == 8 else hex32
    lines = []
    for i, v in enumerate(values):
        comma = "," if i != len(values) - 1 else ""
        lines.append(f"        {i} => {fmt(v)}{comma}")
    return "\n".join(lines)


def write_mem(path, values, width):
    fmt = (lambda v: f"{int(v) & 0xFF:02X}") if width == 8 else (lambda v: f"{int(v) & 0xFFFFFFFF:08X}")
    path.write_text("\n".join(fmt(v) for v in values) + "\n", encoding="ascii")


def write_rom_weight(path, entity, addr_width, values):
    mem_path = OUT / f"{entity}.mem"
    write_mem(mem_path, values, 8)
    abs_mem = str(mem_path).replace("\\", "/")
    text = f"""library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;
library STD;
use STD.TEXTIO.ALL;

entity {entity} is
    generic (
        ADDR_WIDTH : integer := {addr_width};
        DATA_WIDTH : integer := 8
    );
    Port (
        clk   : in STD_LOGIC;
        ena   : in STD_LOGIC;
        addra : in STD_LOGIC_VECTOR(ADDR_WIDTH-1 downto 0);
        douta : out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0)
    );
end {entity};

architecture Behavioral of {entity} is
    type rom_type is array (0 to {len(values) - 1}) of STD_LOGIC_VECTOR(7 downto 0);
    impure function init_rom return rom_type is
        file rom_file : text open read_mode is "{abs_mem}";
        variable rom_line : line;
        variable rom_data : STD_LOGIC_VECTOR(7 downto 0);
        variable rom : rom_type;
    begin
        for i in rom_type'range loop
            readline(rom_file, rom_line);
            hread(rom_line, rom_data);
            rom(i) := rom_data;
        end loop;
        return rom;
    end function;
    constant ROM : rom_type := init_rom;
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if ena = '1' then
                douta <= ROM(to_integer(unsigned(addra)));
            end if;
        end if;
    end process;
end Behavioral;
"""
    path.write_text(text, encoding="ascii")


def write_rom_h1_weight(path, values):
    for n in range(H1):
        write_mem(OUT / f"rom_h1_w_{n:02d}.mem", values[n * INPUTS:(n + 1) * INPUTS], 8)
    mem_paths = [str((OUT / f"rom_h1_w_{n:02d}.mem")).replace("\\", "/") for n in range(H1)]
    bank_inits = "\n".join(
        f'        when {n} => file_name := "{mem_paths[n]}";'
        for n in range(H1)
    )
    text = f"""library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;
library STD;
use STD.TEXTIO.ALL;

entity rom_h1_w is
    Port (
        clka  : in  STD_LOGIC;
        ena   : in  STD_LOGIC;
        addra : in  STD_LOGIC_VECTOR(17 downto 0);
        douta : out STD_LOGIC_VECTOR(7 downto 0)
    );
end rom_h1_w;

architecture Behavioral of rom_h1_w is
    subtype word_type is STD_LOGIC_VECTOR(7 downto 0);
    type bank_type is array (0 to {INPUTS - 1}) of word_type;
    type rom_type is array (0 to {H1 - 1}) of bank_type;
    impure function init_bank(neuron : integer) return bank_type is
        variable file_name : string(1 to {len(mem_paths[0])});
        file rom_file : text;
        variable rom_line : line;
        variable rom_data : word_type;
        variable rom : bank_type;
    begin
        case neuron is
{bank_inits}
        when others => file_name := "{mem_paths[0]}";
        end case;
        file_open(rom_file, file_name, read_mode);
        for i in bank_type'range loop
            readline(rom_file, rom_line);
            hread(rom_line, rom_data);
            rom(i) := rom_data;
        end loop;
        file_close(rom_file);
        return rom;
    end function;
    impure function init_rom return rom_type is
        variable rom : rom_type;
    begin
        for n in rom_type'range loop
            rom(n) := init_bank(n);
        end loop;
        return rom;
    end function;
    constant ROM : rom_type := init_rom;
begin
    process(clka)
        variable flat_addr : integer range 0 to {len(values) - 1};
        variable neuron_addr : integer range 0 to {H1 - 1};
        variable input_addr  : integer range 0 to {INPUTS - 1};
    begin
        if rising_edge(clka) then
            if ena = '1' then
                flat_addr := to_integer(unsigned(addra));
                neuron_addr := flat_addr / {INPUTS};
                input_addr := flat_addr mod {INPUTS};
                douta <= ROM(neuron_addr)(input_addr);
            end if;
        end if;
    end process;
end Behavioral;
"""
    path.write_text(text, encoding="ascii")


def write_rom_bias(path, entity, addr_decl, length, values):
    mem_path = OUT / f"{entity}.mem"
    write_mem(mem_path, values, 32)
    abs_mem = str(mem_path).replace("\\", "/")
    text = f"""library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;
library STD;
use STD.TEXTIO.ALL;

entity {entity} is
    Port (
        clk   : in STD_LOGIC;
        ena   : in STD_LOGIC;
        addra : in STD_LOGIC_VECTOR({addr_decl});
        douta : out STD_LOGIC_VECTOR(31 downto 0)
    );
end {entity};

architecture Behavioral of {entity} is
    type rom_type is array (0 to {length - 1}) of STD_LOGIC_VECTOR(31 downto 0);
    impure function init_rom return rom_type is
        file rom_file : text open read_mode is "{abs_mem}";
        variable rom_line : line;
        variable rom_data : STD_LOGIC_VECTOR(31 downto 0);
        variable rom : rom_type;
    begin
        for i in rom_type'range loop
            readline(rom_file, rom_line);
            hread(rom_line, rom_data);
            rom(i) := rom_data;
        end loop;
        return rom;
    end function;
    constant ROM : rom_type := init_rom;
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if ena = '1' then
                douta <= ROM(to_integer(unsigned(addra)));
            end if;
        end if;
    end process;
end Behavioral;
"""
    path.write_text(text, encoding="ascii")


def export_vhdl(q):
    w1 = np.concatenate([q["w1"][:, n] for n in range(H1)])
    w2 = np.concatenate([q["w2"][:, n] for n in range(H2)])
    w3 = q["w3"][:, 0]
    write_rom_h1_weight(SRC / "rom_h1_w.vhd", w1)
    write_rom_bias(SRC / "rom_h1_b.vhd", "rom_h1_b", "5 downto 0", H1, q["b1"])
    write_rom_weight(SRC / "rom_h2_w.vhd", "rom_h2_w", 11, w2)
    write_rom_bias(SRC / "rom_h2_b.vhd", "rom_h2_b", "4 downto 0", H2, q["b2"])
    write_rom_weight(SRC / "rom_out_w.vhd", "rom_out_w", 5, w3)
    write_rom_bias(SRC / "rom_out_b.vhd", "rom_out_b", "0 downto 0", 1, q["b3"])


def main():
    OUT.mkdir(exist_ok=True)
    x, x_int, y, paths = load_images()
    rng = np.random.default_rng(3)
    cat = np.where(y[:, 0] == 0)[0]
    dog = np.where(y[:, 0] == 1)[0]
    rng.shuffle(cat)
    rng.shuffle(dog)
    val_idx = np.concatenate([cat[:20], dog[:20]])
    train_idx = np.concatenate([cat[20:], dog[20:]])
    rng.shuffle(train_idx)
    rng.shuffle(val_idx)

    print(f"Loaded {len(cat)} cats and {len(dog)} dogs")
    best_p = None
    best_q = None
    best_score = -1.0
    best_metrics = None
    x_aug, x_aug_int, y_aug = build_augmented_training_set(x_int, y, train_idx, copies=5, seed=99)
    aug_train_idx = np.arange(len(y_aug))
    val_offset = len(y_aug)
    x_search = np.concatenate([x_aug, x[val_idx]], axis=0)
    y_search = np.concatenate([y_aug, y[val_idx]], axis=0)
    search_train_idx = aug_train_idx
    search_val_idx = np.arange(val_offset, val_offset + len(val_idx))

    for seed in range(1, 13):
        p = train(x_search, y_search, search_train_idx, search_val_idx, seed=seed, epochs=700)
        q = quantize(p)
        q, output_threshold, threshold_val_acc = tune_output_bias(q, x_int, y, val_idx)
        _, _, _, _, float_logits = forward(x, p)
        float_pred = (sigmoid(float_logits) >= 0.5).astype(np.float32)
        int_pred = int_infer(x_int, q)
        metrics = {
            "train_images": int(len(train_idx)),
            "validation_images": int(len(val_idx)),
            "augmented_training_samples": int(len(search_train_idx)),
            "float_train_accuracy": float((float_pred[train_idx] == y[train_idx]).mean()),
            "float_validation_accuracy": float((float_pred[val_idx] == y[val_idx]).mean()),
            "integer_train_accuracy": float((int_pred[train_idx] == y[train_idx]).mean()),
            "integer_validation_accuracy": float((int_pred[val_idx] == y[val_idx]).mean()),
            "output_threshold_adjustment": int(output_threshold),
            "threshold_tuned_validation_accuracy": float(threshold_val_acc),
            "seed": seed,
            "input_format": "28x28 RGB, each byte is pixel_value - 128 encoded as signed int8",
            "dog_label": 1,
            "cat_label": 0,
            "w_scale": W_SCALE,
            "activation_shift": SHIFT,
        }
        score = metrics["integer_validation_accuracy"]
        print("candidate", json.dumps(metrics, indent=2))
        if score > best_score:
            best_score = score
            best_p = p
            best_q = q
            best_metrics = metrics

    p = best_p
    q = best_q

    _, _, _, _, float_logits = forward(x, p)
    float_pred = (sigmoid(float_logits) >= 0.5).astype(np.float32)
    int_pred = int_infer(x_int, q)
    metrics = {
        "train_images": int(len(train_idx)),
        "validation_images": int(len(val_idx)),
        "augmented_training_samples": int(len(search_train_idx)),
        "float_train_accuracy": float((float_pred[train_idx] == y[train_idx]).mean()),
        "float_validation_accuracy": float((float_pred[val_idx] == y[val_idx]).mean()),
        "integer_train_accuracy": float((int_pred[train_idx] == y[train_idx]).mean()),
        "integer_validation_accuracy": float((int_pred[val_idx] == y[val_idx]).mean()),
        "selected_seed": best_metrics["seed"],
        "output_threshold_adjustment": int(best_metrics["output_threshold_adjustment"]),
        "input_format": "28x28 RGB, each byte is pixel_value - 128 encoded as signed int8",
        "dog_label": 1,
        "cat_label": 0,
        "w_scale": W_SCALE,
        "activation_shift": SHIFT,
    }
    print(json.dumps(metrics, indent=2))
    export_vhdl(q)
    np.savez_compressed(OUT / "cat_dog_model_quantized.npz", **q)
    (OUT / "metrics.json").write_text(json.dumps(metrics, indent=2), encoding="ascii")
    (OUT / "validation_files.txt").write_text("\n".join(paths[i] for i in val_idx), encoding="ascii")
    print("Exported VHDL ROM files and trained_model/cat_dog_model_quantized.npz")


if __name__ == "__main__":
    main()
