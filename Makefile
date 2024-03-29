POD_NAME ?= dragline
STORAGE_BUCKET ?= fecambucket
STORAGE_IMAGE ?= docker.io/bitnami/minio:2021.4.6
STORAGE_CONTAINER_NAME ?= fecam-storage
STORAGE_ACCESS_KEY ?= minio-access-key
STORAGE_ACCESS_SECRET ?= minio-secret-key
STORAGE_PORT ?= 9000

IMAGE_NAMESPACE ?= localhost
APACHE_TIKA_IMAGE_NAME ?= apache-tika
APACHE_TIKA_IMAGE_TAG ?= latest
APACHE_TIKA_CONTAINER_NAME ?= apache-tika

BATCH_SIZE ?= 32
DATA_DIR ?= "data"
EMBEDDING_DIM ?= 50
EMBEDDING_FILE ?= "$(DATA_DIR)/embeddings/glove_s50.txt"
ENV_NAME ?= $(shell conda env export --json | jq ".name")
EPOCHS ?= 1000
MODEL_NAME ?= "text_autoencoder"
MODEL_PATH ?= "$(PWD)/models"
VOCAB_FILE ?= "$(DATA_DIR)/bertimbau_base_vocab.txt"
VOCAB_SIZE ?= $(shell cat $(VOCAB_FILE) | wc -l)
WIKIPEDIA_DATASET_SIZE ?= 1.0
WIKIPEDIA_DATA_DIR ?= "$(DATA_DIR)/wikipedia"
PATIENCE ?= 20
LEARNING_RATE ?= 0.00001
TRANSFORMER_ADDITIONAL_ARGS ?=

python_script = PYTHONPATH=$(PWD) \
	BATCH_SIZE=$(BATCH_SIZE) \
	EPOCHS=$(EPOCHS) \
	MODEL_NAME=$(MODEL_NAME) \
	MODEL_PATH=$(MODEL_PATH) \
	TF_CPP_MIN_LOG_LEVEL=2 \
	VOCAB_FILE=$(VOCAB_FILE) \
	VOCAB_SIZE=$(VOCAB_SIZE) \
	WIKIPEDIA_DATASET_SIZE=$(WIKIPEDIA_DATASET_SIZE) \
	WIKIPEDIA_DATA_DIR=$(WIKIPEDIA_DATA_DIR) \
	EMBEDDING_FILE=$(EMBEDDING_FILE) \
	EMBEDDING_DIM=$(EMBEDDING_DIM) \
	PATIENCE=$(PATIENCE) \
	LEARNING_RATE=$(LEARNING_RATE) \
	python $(1)

.PHONY: format
format:
	black gazettes/*.py scripts/*.py tests/*.py

.PHONY: tests
tests: format
	python -m unittest -f tests/*.py

.PHONY: tests-preprocessing
tests-preprocessing: format
	cp data/querido_diario/1302603/2022-06-15/054847a8785e44e832b796ef21f5cd4619d32173.txt ./tests/
	cp data/querido_diario/2507507/2022-06-20/a8b95c77d984aa228dc8c9c6094b526857df6878.txt ./tests/
	cp data/querido_diario/2507507/2022-06-10/c3789a9296485ff74a139114f5925e71c4f548d9.txt ./tests/
	python -m unittest -f tests/preprocessing_tests.py

.PHONY: update-conda-env
update-conda-env:
	echo "Exporting $(ENV_NAME)"
	conda env export -n $(ENV_NAME) > $(ENV_NAME)_env.yml

.PHONY: train-lstm-autoencoder
train-lstm-autoencoder: VOCAB_SIZE=10000
train-lstm-autoencoder: tests
	PYTHONPATH=$(PWD) TF_GPU_THREAD_MODE=gpu_private python scripts/text_autoencoder.py \
		--batch-size $(BATCH_SIZE) \
		--bidirectional-hidden-layers \
		--dataset-dir $(WIKIPEDIA_DATA_DIR) \
		--embedding-dimensions 50 \
		--embedding-file "$(DATA_DIR)/wikipedia/embeddings.txt" \
		--epochs $(EPOCHS) \
		--hidden-layers-count 1 \
		--learning-rate $(LEARNING_RATE) \
		--model-name lstm-autoencoder \
		--rnn-type lstm \
		--save-model-at models/lstm-autoencoder \
		--tokenizer-config-file $(WIKIPEDIA_DATA_DIR)/tokenizer.json \
		--vocab-size $(VOCAB_SIZE) \
		--vocabulary-file $(WIKIPEDIA_DATA_DIR)/vocabulary \
		--from-scratch --train --evaluate

.PHONY: train-gru-autoencoder
train-gru-autoencoder: VOCAB_SIZE=10000
train-gru-autoencoder: tests
	TF_GPU_THREAD_MODE='gpu_private'  PYTHONPATH=$(PWD) \
		python scripts/text_autoencoder.py \
		--batch-size $(BATCH_SIZE) \
		--bidirectional-hidden-layers \
		--dataset-dir $(WIKIPEDIA_DATA_DIR) \
		--embedding-dimensions 50 \
		--embedding-file "$(DATA_DIR)/wikipedia/embeddings.txt" \
		--epochs $(EPOCHS) \
		--hidden-layers-count 1 \
		--learning-rate $(LEARNING_RATE) \
		--model-name gru-autoencoder \
		--rnn-type gru \
		--save-model-at models/gru-autoencoder \
		--tokenizer-config-file $(WIKIPEDIA_DATA_DIR)/tokenizer.json \
		--vocab-size $(VOCAB_SIZE) \
		--vocabulary-file $(WIKIPEDIA_DATA_DIR)/vocabulary \
		--train --evaluate


.PHONY: train-transformer-autoencoder
train-transformer-autoencoder: format
	PYTHONPATH=$(PWD) python scripts/text_autoencoder_transformer.py

.PHONY: download_wikipedia_dataset
download_wikipedia_dataset: tests
	PYTHONPATH=$(PWD) python scripts/download_wikipedia_data.py


.PHONY: download_bertimbau_tensorflow_checkpoint
download_bertimbau_tensorflow_checkpoint:
	curl -o $(DATA_DIR)/bertimbau-base-portuguese-cased_tensorflow_checkpoint.zip https://neuralmind-ai.s3.us-east-2.amazonaws.com/nlp/bert-base-portuguese-cased/bert-base-portuguese-cased_tensorflow_checkpoint.zip
	curl -o $(DATA_DIR)/bertimbau-base-vocab.txt https://neuralmind-ai.s3.us-east-2.amazonaws.com/nlp/bert-base-portuguese-cased/vocab.txt
	curl -o $(DATA_DIR)/bertimbau-large-portuguese-cased_tensorflow_checkpoint.zip https://neuralmind-ai.s3.us-east-2.amazonaws.com/nlp/bert-large-portuguese-cased/bert-large-portuguese-cased_tensorflow_checkpoint.zip
	curl -o $(DATA_DIR)/bertimbau-large-vocab.txt https://neuralmind-ai.s3.us-east-2.amazonaws.com/nlp/bert-large-portuguese-cased/vocab.txt


.PHONY: predict-autoencoder
predict-autoencoder: VOCAB_FILE=$(DATA_DIR)/wikipedia_vocab
predict-autoencoder:
	PYTHONPATH=$(PWD) python scripts/predict_text.py \
		   -m models/${MODEL_NAME} \
		   --embeddings-file=$(EMBEDDING_FILE) \
		   --embeddings-dimensions=$(EMBEDDING_DIM) \
		   --dataset-dir=$(WIKIPEDIA_DATA_DIR)/test \
		   --vocab-size=$(VOCAB_SIZE)


.PHONY: build-vocab
build-vocab: VOCAB_FILE=$(DATA_DIR)/wikipedia_vocab
build-vocab:
	$(call python_script, scripts/build_vocabulary.py)


.PHONY: clean-cache
clean-cache:
	rm -rf $(WIKIPEDIA_DATA_DIR)/cache
	rm -rf $(WIKIPEDIA_DATA_DIR)/train/cache
	rm -rf $(WIKIPEDIA_DATA_DIR)/test/cache
	rm -rf $(WIKIPEDIA_DATA_DIR)/evaluation/cache

.PHONY: clean-wikipedia
clean-wikipedia:
	rm -rf $(WIKIPEDIA_DATA_DIR)

.PHONY: download-word-embeddings
download-word-embeddings:
	mkdir -p $(DATA_DIR)/embeddings
	curl -o $(DATA_DIR)/embeddings/glove_s50.zip http://143.107.183.175:22980/download.php?file=embeddings/glove/glove_s50.zip
	unzip -d $(DATA_DIR)/embeddings $(DATA_DIR)/embeddings/glove_s50.zip

.PHONY: download-querido-diario-files
download-querido-diario-files:
	mkdir -p $(DATA_DIR)/querido_diario
	s3cmd get --verbose --skip-existing s3://querido-diario/ $(DATA_DIR)/querido_diario --recursive

.PHONY: preprocess_gazettes
preprocess_gazettes:
	$(call python_script, scripts/preprocess_querido_diario_files.py)

.PHONY: preprocess_wikipedia
preprocess_wikipedia:
	$(call python_script, scripts/preprocess_wikipedia.py)

.PHONY: publish_gazettes_sentences
publish_gazettes_sentences:
	$(call python_script, scripts/publish_querido_diario_dataset.py)

.PHONY: train-querido-diario-autoencoder
train-querido-diario-autoencoder:
	$(call python_script, scripts/querido_diario_autoencoder.py)

.PHONY: train-latent-representation-classifier
train-latent-representation-classifier: format
	$(call python_script, scripts/latent_representation_classifier.py)

.PHONY: train-latent-space-representation-edit-model
train-latent-space-representation-edit-model: format
	PYTHONPATH=$(PWD) python scripts/text_style_transfer.py \
	  --name latent_space_representation_edit_model_wang_controllable_2019 \
	  --checkpoint neuralmind/bert-base-portuguese-cased \
	  --batch-size 32 \
	  #--debug


