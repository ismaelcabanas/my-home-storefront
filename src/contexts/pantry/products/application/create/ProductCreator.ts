import { Service } from "diod";

import { UuidGenerator } from "../../../../shared/domain/UuidGenerator";
import { Product } from "../../domain/Product";
import { ProductAlreadyExistsError } from "../../domain/ProductAlreadyExistsError";
import { ProductName } from "../../domain/ProductName";
import { ProductRepository } from "../../domain/ProductRepository";

@Service()
export class ProductCreator {
	constructor(
		private readonly repository: ProductRepository,
		private readonly uuidGenerator: UuidGenerator,
	) {}

	async create(name: string, currentStock: number): Promise<void> {
		const productName = new ProductName(name);

		const existing = await this.repository.searchByName(productName);
		if (existing) {
			throw new ProductAlreadyExistsError(name);
		}

		const id = await this.uuidGenerator.generate();
		const product = Product.create(id, name, currentStock);

		await this.repository.save(product);
	}
}
