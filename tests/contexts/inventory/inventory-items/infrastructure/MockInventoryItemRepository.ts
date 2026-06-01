import { Cursor } from "../../../../../src/contexts/inventory/inventory-items/domain/Cursor";
import { InventoryItem } from "../../../../../src/contexts/inventory/inventory-items/domain/InventoryItem";
import { InventoryItemNotFoundError } from "../../../../../src/contexts/inventory/inventory-items/domain/InventoryItemNotFoundError";
import { InventoryItemRepository } from "../../../../../src/contexts/inventory/inventory-items/domain/InventoryItemRepository";
import {
	createPaginatedInventoryItems,
	emptyPaginatedInventoryItems,
	type PaginatedInventoryItems,
} from "../../../../../src/contexts/inventory/inventory-items/domain/PaginatedInventoryItems";

export class MockInventoryItemRepository implements InventoryItemRepository {
	private readonly items = new Map<string, InventoryItem>();
	private readonly savedItems: InventoryItem[] = [];
	private readonly findByIdMock = new Map<string, InventoryItem | null>();
	private readonly expectedSaveItems: InventoryItem[] = [];

	async save(item: InventoryItem): Promise<void> {
		this.items.set(item.id.value, item);
		this.savedItems.push(item);
	}

	async searchById(id: string): Promise<InventoryItem | null> {
		if (this.findByIdMock.has(id)) {
			return this.findByIdMock.get(id) ?? null;
		}

		return this.items.get(id) ?? null;
	}

	async findById(id: string): Promise<InventoryItem> {
		const item = await this.searchById(id);
		if (item === null) {
			throw new InventoryItemNotFoundError(id);
		}

		return item;
	}

	async searchAll(
		limit: number,
		cursor: string | null,
	): Promise<PaginatedInventoryItems> {
		// Get all items and sort by name ASC, created_at ASC
		const allItems = Array.from(this.items.values()).sort((a, b) => {
			const nameComparison = a.name.value.localeCompare(b.name.value);
			if (nameComparison !== 0) {
				return nameComparison;
			}

			return a.createdAt.getTime() - b.createdAt.getTime();
		});

		// Find starting position based on cursor
		let startIndex = 0;
		if (cursor !== null && cursor !== "") {
			const decodedCursor = Cursor.decode(cursor);
			startIndex = allItems.findIndex(
				(item) =>
					item.name.value > decodedCursor.name ||
					(item.name.value === decodedCursor.name &&
						item.createdAt > decodedCursor.createdAt),
			);
			if (startIndex === -1) {
				startIndex = allItems.length;
			}
		}

		// Get items starting from cursor position
		const itemsFromCursor = allItems.slice(startIndex);

		// Empty result set
		if (itemsFromCursor.length === 0) {
			return emptyPaginatedInventoryItems();
		}

		// Determine if there are more results
		const hasMore = itemsFromCursor.length > limit;
		const pageItems = itemsFromCursor.slice(0, limit);

		let nextCursor: string | null = null;
		if (hasMore) {
			const lastItem = pageItems[pageItems.length - 1];
			nextCursor = new Cursor(
				lastItem.name.value,
				lastItem.createdAt,
			).encode();
		}

		return createPaginatedInventoryItems(
			pageItems.map((item) => item.toPrimitives()),
			nextCursor,
			hasMore,
		);
	}

	async searchByRequiresPurchase(
		limit: number,
		cursor: string | null,
	): Promise<PaginatedInventoryItems> {
		// Get all items requiring purchase and sort by name ASC, created_at ASC
		const allItems = Array.from(this.items.values())
			.filter((item) => item.requiresPurchase)
			.sort((a, b) => {
				const nameComparison = a.name.value.localeCompare(b.name.value);
				if (nameComparison !== 0) {
					return nameComparison;
				}

				return a.createdAt.getTime() - b.createdAt.getTime();
			});

		// Find starting position based on cursor
		let startIndex = 0;
		if (cursor !== null && cursor !== "") {
			const decodedCursor = Cursor.decode(cursor);
			startIndex = allItems.findIndex(
				(item) =>
					item.name.value > decodedCursor.name ||
					(item.name.value === decodedCursor.name &&
						item.createdAt > decodedCursor.createdAt),
			);
			if (startIndex === -1) {
				startIndex = allItems.length;
			}
		}

		// Get items starting from cursor position
		const itemsFromCursor = allItems.slice(startIndex);

		// Empty result set
		if (itemsFromCursor.length === 0) {
			return emptyPaginatedInventoryItems();
		}

		// Determine if there are more results
		const hasMore = itemsFromCursor.length > limit;
		const pageItems = itemsFromCursor.slice(0, limit);

		let nextCursor: string | null = null;
		if (hasMore) {
			const lastItem = pageItems[pageItems.length - 1];
			nextCursor = new Cursor(
				lastItem.name.value,
				lastItem.createdAt,
			).encode();
		}

		return createPaginatedInventoryItems(
			pageItems.map((item) => item.toPrimitives()),
			nextCursor,
			hasMore,
		);
	}

	shouldSave(expectedItem: InventoryItem): void {
		this.expectedSaveItems.push(expectedItem);
	}

	shouldSearchById(id: string, mockItem: InventoryItem | null): void {
		this.findByIdMock.set(id, mockItem);
	}

	shouldFindById(id: string, mockItem: InventoryItem | null): void {
		this.findByIdMock.set(id, mockItem);
	}

	verify(): void {
		expect(this.savedItems).toHaveLength(this.expectedSaveItems.length);

		for (let i = 0; i < this.expectedSaveItems.length; i++) {
			const expected = this.expectedSaveItems[i];
			const actual = this.savedItems[i];

			expect(actual.id.value).toBe(expected.id.value);
			expect(actual.name.value).toBe(expected.name.value);
			expect(actual.state.value).toBe(expected.state.value);
		}
	}
}
