const {InstancesClient} = require('@google-cloud/compute');

const instancesClient = new InstancesClient();

function decodeEvent(cloudEvent) {
  const message = cloudEvent.data && cloudEvent.data.message ? cloudEvent.data.message : {};
  const encoded = message.data || '';

  if (!encoded) {
    return {};
  }

  return JSON.parse(Buffer.from(encoded, 'base64').toString('utf8'));
}

exports.stopLabVm = async cloudEvent => {
  const payload = decodeEvent(cloudEvent);
  const costAmount = Number(payload.costAmount || 0);
  const budgetAmount = Number(payload.budgetAmount || 0);

  if (!Number.isFinite(costAmount) || !Number.isFinite(budgetAmount)) {
    console.log('Skipping invalid billing notification payload.');
    return;
  }

  if (costAmount <= budgetAmount) {
    console.log(`No action necessary. Current cost ${costAmount} is within budget ${budgetAmount}.`);
    return;
  }

  const project = process.env.TARGET_PROJECT_ID;
  const zone = process.env.TARGET_INSTANCE_ZONE;
  const instance = process.env.TARGET_INSTANCE;

  const [vm] = await instancesClient.get({
    project,
    zone,
    instance,
  });

  if (vm.status !== 'RUNNING') {
    console.log(`No action necessary. Instance ${instance} is currently ${vm.status}.`);
    return;
  }

  await instancesClient.stop({
    project,
    zone,
    instance,
  });

  console.log(`Stopped instance ${instance} in ${zone} because cost ${costAmount} exceeded budget ${budgetAmount}.`);
};
