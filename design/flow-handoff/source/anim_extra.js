  // the look's settings, for the GLFX pass
  glfxParams() {
    const o = this.o;
    return { contrast: o.contrast, bright: o.bright, saturate: o.saturate, hue: o.hue, posterize: o.posterize, duotone: o.duotone,
      dk: this.pal.boxDark, lt: o.duoLight === 'bg' ? this.pal.bgColor : o.duoLight === 'white' ? '#FFFFFF' : this.pal.boxLight,
      sketch: o.sketch && !window.__plNoRough, skCol: this.colour(o.skCol), skWidth: o.skWidth, skRough: o.skRough, skScale: o.skScale, skGrain: o.skGrain,
      skDouble: o.skDouble, skWarp: o.skWarp, seed: GLFX.boilSeed(o.sketch ? o.skBoil : 0) };
  }
