const firebaseService = require('./services/firebase');

async function runSeed() {
  console.log('🚀 [Seed CLI] Starting dummy data upload to Firebase Realtime Database...');
  const result = await firebaseService.seedAllDummyData();
  console.log('✨ Seed Operation Result:');
  console.log(JSON.stringify(result, null, 2));
  console.log('\n📊 Database Status:');
  console.log(JSON.stringify(firebaseService.getStatus(), null, 2));
  process.exit(0);
}

runSeed().catch((err) => {
  console.error('Fatal seed error:', err);
  process.exit(1);
});
