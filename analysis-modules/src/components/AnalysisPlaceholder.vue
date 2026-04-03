<script setup>
const plannedModules = [
  'Heatmaps de position des joueurs',
  'Analyse de formation',
  'Statistiques individuelles',
  'Analyse tactique',
]
</script>

<template>
  <div class="placeholder">
    <h1>MeeHawk Analysis Modules</h1>
    <p>Modules d'analyse avances - coming soon</p>
    <ul>
      <li v-for="mod in plannedModules" :key="mod">{{ mod }}</li>
    </ul>
  </div>
</template>

<style scoped>
.placeholder {
  max-width: 600px;
  margin: 80px auto;
  text-align: center;
  font-family: sans-serif;
  color: #c9d1d9;
}
h1 { color: #58a6ff; margin-bottom: 12px; }
ul { list-style: none; margin-top: 16px; }
li { padding: 8px; background: #161b22; margin: 4px 0; border-radius: 6px; }
</style>
