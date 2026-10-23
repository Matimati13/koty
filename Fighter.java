package pl.koty.app;

public class Fighter {
    public static final String[] SKILLS = {"Pazur", "Puchata tarcza", "Urocze oczka", "Leniwy skok"};
    public static final int[] CD = {0, 3, 3, 4};

    public final String name;
    public final int[] st;
    public final int maxHp;
    public int hp;
    public int shield;
    public final int[] cd = new int[4];
    public byte[] photo = new byte[0];

    public Fighter(String name, int[] st) {
        this.name = name;
        this.st = st;
        this.maxHp = 30 + st[0] * 5;
        this.hp = maxHp;
    }

    public static int power(int s, int[] st) {
        switch (s) {
            case 0: return 5 + st[1] * 12 / 10;
            case 1: return Math.min(80, 20 + st[0] * 6);
            case 2: return 4 + st[2] * 3 / 2;
            default: return 6 + st[3] * 25 / 10;
        }
    }

    public static String describe(int s, int[] st) {
        int p = power(s, st);
        if (s == 1) return "Osłona −" + p + "% następnego ciosu";
        if (s == 2) return "Leczy " + p + " HP";
        return "Obrażenia " + p;
    }

    public void startTurn() {
        for (int i = 0; i < 4; i++) {
            if (cd[i] > 0) cd[i]--;
        }
    }

    public int hit(int p) {
        int d = p * (100 - shield) / 100;
        if (d < 1) d = 1;
        shield = 0;
        hp = Math.max(0, hp - d);
        return d;
    }

    public String use(int s, Fighter target) {
        cd[s] = CD[s];
        int p = power(s, st);
        if (s == 1) {
            shield = p;
            return name + " stroszy futro (−" + p + "% następnego ciosu).";
        }
        if (s == 2) {
            int before = hp;
            hp = Math.min(maxHp, hp + p);
            return name + " robi słodkie oczka i leczy " + (hp - before) + " HP.";
        }
        int d = target.hit(p);
        return name + " używa: " + SKILLS[s] + " (−" + d + " HP).";
    }
}